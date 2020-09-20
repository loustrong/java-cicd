#!/bin/sh

function get_version() {

    if test "$GITLAB_KEY" == "" && test "${SOURCEPJ}" == "true"; then
        echo "Permission denied"
        exit 0
    fi

    branch="$CI_COMMIT_REF_NAME"
    a="$CI_COMMIT_REF_NAME"

    b="fix-"
    prefix="${a/$b*/$b}"
    if test $prefix == $b; then branch=$prefix; fi

    b="pre-production"
    prefix="${a/$b*/$b}"
    if test $prefix == $b; then branch=$prefix; fi

    b="production"
    prefix="${a/$b*/$b}"
    if test $prefix == $b; then branch=$prefix; fi

    echo "$branch"

    # default SYS_VER to be NA
    SYS_VER="NA"
    echo "export SYS_VER=${SYS_VER};" >>build-vars.sh

    if test "${branch}" == "master"; then
        echo "master dont need setup, exit ci."
        exit 0
    fi

    # Get PRE Commit SHA

    TMP=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/tags")

    # hotfix，先抓自己，如果自己有Tag，建立hotfix tag，然後跳過
    if test "${branch}" == "fix-"; then

        if test "${SOURCEPJ}" != "true"; then
            echo "Not Source Code Project, exit hotfix ci."
            exit 0
        fi

        VER=$(jq -r 'map(select(.target | contains ($newVal))) | .[] .name' --arg newVal "$CI_COMMIT_SHORT_SHA" <<<"$TMP")
        echo "$VER"
        if test "${VER}" != ""; then
            echo "new hotfix, exit!"
            curl --request POST --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/tags?tag_name=hotfix-${VER}&ref=${CI_COMMIT_REF_NAME}"
            exit 0
        fi
    fi

    # QAS \ hotfix 抓上層
    if test "${branch}" == "pre-production" || test "${branch}" == "fix-"; then
        PRE_SHA=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/commits/${CI_COMMIT_SHORT_SHA}" | jq -r '.parent_ids')
    fi

    # PRD抓上兩層
    if test "${branch}" == "production"; then
        # 第一層
        PRE_SHA=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/commits/${CI_COMMIT_SHORT_SHA}" | jq -r '.parent_ids')
        LEN=$(jq '. | length-1' <<<"${PRE_SHA}")
        if [[ $((${LEN} + 0)) -lt 0 ]]; then
            echo "Cant get upstream commit!!"
            exit 0
        fi
        PRE_SHA=$(jq -r '.[$newVal|tonumber]' --arg newVal ${LEN} <<<"${PRE_SHA}")
        # 第二層
        PRE_SHA=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/commits/${PRE_SHA}" | jq -r '.parent_ids')
    fi

    # forkprd抓上三層
    if test "${branch}" == "forkprd"; then
        # 第一層
        PRE_SHA=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/commits/${CI_COMMIT_SHORT_SHA}" | jq -r '.parent_ids')
        LEN=$(jq '. | length-1' <<<"${PRE_SHA}")
        if [[ $((${LEN} + 0)) -lt 0 ]]; then
            echo "Cant get upstream commit!!"
            exit 0
        fi
        PRE_SHA=$(jq -r '.[$newVal|tonumber]' --arg newVal ${LEN} <<<"${PRE_SHA}")
        # 第二層
        PRE_SHA=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/commits/${PRE_SHA}" | jq -r '.parent_ids')
        LEN=$(jq '. | length-1' <<<"${PRE_SHA}")
        if [[ $((${LEN} + 0)) -lt 0 ]]; then
            echo "Cant get upstream commit!!"
            exit 0
        fi
        PRE_SHA=$(jq -r '.[$newVal|tonumber]' --arg newVal ${LEN} <<<"${PRE_SHA}")
        # 第三層
        PRE_SHA=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/commits/${PRE_SHA}" | jq -r '.parent_ids')
    fi

    LEN=$(jq '. | length-1' <<<"${PRE_SHA}")

    # 如果是hotfix，改抓第一個節點，防止可能有多人協作
    if test "${branch}" == "fix-"; then LEN=0; fi

    if [[ $((${LEN} + 0)) -lt 0 ]]; then
        echo "Cant get upstream commit!!"
        exit 0
    fi
    PRE_SHA=$(jq -r '.[$newVal|tonumber]' --arg newVal ${LEN} <<<"${PRE_SHA}")
    echo "${PRE_SHA}"

    # hotfix，會依SHA值去抓hotfix-的TAG
    if test "${branch}" == "fix-"; then
        VER=$(jq -r 'map(select(.target | contains ($newVal))) | map(select(.name | contains ("hotfix-"))) | .[].name' --arg newVal "$PRE_SHA" <<<"$TMP")
    else VER=$(jq -r 'map(select(.target | contains ($newVal))) | map(select(.name | contains ("hotfix-") | not)) | .[].name' --arg newVal "$PRE_SHA" <<<"$TMP"); fi

    echo "$VER"

    if test "${VER}" == ""; then
        echo "VER to NA"
        VER="NA"
    fi

    # 如果是hotfix，要去找這是第幾次的修正，並抓到前版本號
    if test "${branch}" == "fix-" && test "${SOURCEPJ}" == "true"; then
        echo "Hotfix Flow!"
        b="-"
        VER="${VER/*$b/$b}"
        echo "$VER"
        VER=${VER:1}
        echo "$VER"

        # 為了後面易抓版本號，建立或移動hotfix tag prefix
        curl --request DELETE --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/tags/hotfix-${VER}"
        curl --request POST --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/tags?tag_name=hotfix-${VER}&ref=${CI_COMMIT_REF_NAME}"

        hotfixver=$(jq -r 'map(select(.name | contains ($newVal))) | length-1' --arg newVal "$VER" <<<"$TMP")
        VER=${VER}.$((${hotfixver}))

    fi # end hotfix

    echo "version:${VER}"

    echo "export SYS_VER=${VER};" >>build-vars.sh

}

function docker_build() {

    if test "$GITLAB_KEY" == "" && test "${SOURCEPJ}" == "true"; then
        echo "Permission denied"
        exit 0
    fi

    branch="$CI_COMMIT_REF_NAME"
    a="$CI_COMMIT_REF_NAME"

    b="fix-"
    prefix="${a/$b*/$b}"
    if test $prefix == $b; then branch=$prefix; fi

    b="pre-production"
    prefix="${a/$b*/$b}"
    if test $prefix == $b; then branch=$prefix; fi

    b="production"
    prefix="${a/$b*/$b}"
    if test $prefix == $b; then branch=$prefix; fi

    echo "$branch"

    VER="${SYS_VER}"
    echo "SYS_VER:${VER}"

    if test "${branch}" == "fix-" && test "${VER}" == "NA"; then
        echo "Hotfix branch exit!"
        exit 0
    fi

    # PRD \ hotfix
    # PRD tag become latest
    if test "${branch}" == "production"; then
        echo "PRD!"
        tag="lateset"
        echo "${VER}" >${VERSION_FILE}
    fi
    # hotfix tag use use upstream (SYS_VER) Version
    if test "${branch}" == "fix-"; then
        echo "HOTFIX!"
        tag=${VER}
        echo "${VER}" >${VERSION_FILE}
    fi

    # master use currect Version + 1
    if test "${branch}" == "master"; then
        echo "MASTER!"
        VER_S=$((${VER_S} + 1))
        tag="${VER_M}${VER_S}"
        echo "${tag}" >${VERSION_FILE}
        echo "export SYS_VER=${VER_M}${VER_S};" >>build-vars-docker_build.sh
    else
        echo "export SYS_VER=${VER};" >>build-vars-docker_build.sh
    fi

    if test "${branch}" == "pre-production"; then
        echo "QAS no need to build image."
        exit 0
    fi

    # if master, update Tag & Version
    echo ${BUILD_IMAGE_NAME}:${tag}

    # Docker build & push harbor
    docker build -t ${BUILD_IMAGE_NAME}:${tag} --rm=true .

    if [ -f "goss.yaml" ]; then
        # 檔案 goss 存在
        echo "Testing image..."
        if test "${TEST_PORT}" != ""; then
            echo "Port Working？"
            GOSS_FILES_STRATEGY=cp dgoss run -p ${TEST_PORT} ${BUILD_IMAGE_NAME}:${tag}
        else 
            echo "Job Running？"
            GOSS_FILES_STRATEGY=cp dgoss run ${BUILD_IMAGE_NAME}:${tag}
        fi
        echo "Testing image OK"
    fi

    docker tag ${BUILD_IMAGE_NAME}:${tag} ${HARBOR_URL}/${HARBOR_PROJECT}/${BUILD_IMAGE_NAME}:${tag}
    echo "$HARBOR_PASSWORD" | docker login -u "$HARBOR_USER" --password-stdin ${HARBOR_URL}
    docker push ${HARBOR_URL}/${HARBOR_PROJECT}/${BUILD_IMAGE_NAME}:${tag}

    if test "${branch}" == "master"; then curl --request PUT --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/variables/VER_S" --form "value=${VER_S}"; fi
    if test "${branch}" == "master"; then curl --request POST --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/tags?tag_name=${VER_M}${VER_S}&ref=${CI_COMMIT_REF_NAME}"; fi
    if test "${branch}" == "fix-"; then curl --request POST --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/repository/tags?tag_name=${tag}&ref=${CI_COMMIT_REF_NAME}"; fi

}

function cd_update() {
    if test "$GITLAB_KEY" == "" && test "${SOURCEPJ}" == "true"; then
        echo "Permission denied"
        exit 0
    fi

    branch="$CI_COMMIT_REF_NAME"
    a="$CI_COMMIT_REF_NAME"

    b="fix-"
    prefix="${a/$b*/$b}"
    if test $prefix == $b; then branch=$prefix; fi

    b="pre-production"
    prefix="${a/$b*/$b}"
    if test $prefix == $b; then branch=$prefix; fi

    b="production"
    prefix="${a/$b*/$b}"
    if test $prefix == $b; then branch=$prefix; fi

    echo "$branch"

    PJID=${CI_PROJECT_ID}
    K8S_API=""
    K8S_KEY=""

    # configMap計算所需
    CFG_VERSION_RECORD=""
    CONFIG_LATEST=""
    LATEST_VAR=""
    RECORD_VAR=""

    if test "${branch}" == "master" && test "${SOURCEPJ}" == "true"; then
        echo "update DEV Project"
        K8S_API=${K8S_DEV_API}
        K8S_KEY=${K8S_DEV_KEY}
        CFG_VERSION_RECORD=${CFG_RECORD_DEV}
        CONFIG_LATEST=${CFG_LATEST_DEV}
        LATEST_VAR="CFG_LATEST_DEV"
        RECORD_VAR="CFG_RECORD_DEV"

    elif test "${branch}" == "pre-production" && test "${SOURCEPJ}" == "true"; then
        echo "update QAS Project"
        K8S_API=${K8S_QAS_API}
        K8S_KEY=${K8S_QAS_KEY}
        CFG_VERSION_RECORD=${CFG_RECORD_QAS}
        CONFIG_LATEST=${CFG_LATEST_QAS}
        LATEST_VAR="CFG_LATEST_QAS"
        RECORD_VAR="CFG_RECORD_QAS"

    elif test "${branch}" == "fix-" && test "${SOURCEPJ}" == "true"; then
        echo "Hotfix!! update DEV Project"
        K8S_API=${K8S_DEV_API}
        K8S_KEY=${K8S_DEV_KEY}
        CFG_VERSION_RECORD=${CFG_RECORD_DEV}
        CONFIG_LATEST=${CFG_LATEST_DEV}
        LATEST_VAR="CFG_LATEST_DEV"
        RECORD_VAR="CFG_RECORD_DEV"

    elif test "${branch}" == "production" && test "${SOURCEPJ}" == "true"; then
        echo "update PRD Project"
        K8S_API=${K8S_PRD_API}
        K8S_KEY=${K8S_PRD_KEY}
        CFG_VERSION_RECORD=${CFG_RECORD_PRD}
        CONFIG_LATEST=${CFG_LATEST_PRD}
        LATEST_VAR="CFG_LATEST_PRD"
        RECORD_VAR="CFG_RECORD_PRD"

    elif test "${branch}" == "forkprd"; then
        echo "update FORK Project"
        PJID=${PROJECTID}
        K8S_API=${K8S_FK_API}
        K8S_KEY=${K8S_FK_KEY}
        CFG_VERSION_RECORD=${CFG_RECORD_PRD}
        CONFIG_LATEST=${CFG_LATEST_PRD}
        LATEST_VAR="CFG_LATEST_PRD"
        RECORD_VAR="CFG_RECORD_PRD"

    elif test "${branch}" == "production" && test ${AUTOUPDATE} == "true"; then
        echo "auto update PRD Project"
        PJID=${PROJECTID}
        K8S_API=${K8S_FK_API}
        K8S_KEY=${K8S_FK_KEY}
        CFG_VERSION_RECORD=${CFG_RECORD_PRD}
        CONFIG_LATEST=${CFG_LATEST_PRD}
        LATEST_VAR="CFG_LATEST_PRD"
        RECORD_VAR="CFG_RECORD_PRD"

    else
        echo "No Need to update"
        exit 0
    fi
    # echo "Call ${K8S_API}"

    VER=${SYS_VER}

    # 當前版本號 VER
    echo "${VER}"

    if test "${VER}" == "NA"; then
        echo "No New Version to update, exit"
        exit 0
    fi

    BUILD_IMAGE_NAME=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${PJID}/variables/BUILD_IMAGE_NAME" | jq -r '.value')
    HARBOR_URL=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${PJID}/variables/HARBOR_URL" | jq -r '.value')
    HARBOR_PROJECT=$(curl --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${PJID}/variables/HARBOR_PROJECT" | jq -r '.value')
    pod_upgrade_body=$(curl -H "Authorization:${K8S_KEY}" -H "Content-Type:application/json" -X GET ${K8S_API})

    # 抓回之前Config設定
    cfg=$(jq -r '.volumes' <<<$pod_upgrade_body)
    echo $cfg

    vol=$(jq -r '.containers[].volumeMounts' <<<$pod_upgrade_body)
    echo $vol

    # 抓回之前版本號 prever
    prever=$(jq -r '.containers[0].image | split(":")[1]' <<<$pod_upgrade_body)
    echo $prever

    # 檢查之前版本號，是否是最新的？
    UPDATE_LATEST_CONFIG="false"
    ISHOTFIX="true"

    echo "CFG_VERSION_RECORD"
    echo $CFG_VERSION_RECORD

    CHKTMP=$(jq --arg key "${prever}" 'has($key)' <<<$CFG_VERSION_RECORD)
    echo $CHKTMP

    if test "${CONFIG_LATEST}" != ""; then
        echo "LATEST CONFIG EXIST!"
        # 存在，比較版本號，是否為最新的
        pv1=$(jq -r 'split(".")[0]' <<<"\"$prever\"")  # " 
        pv2=$(jq -r 'split(".")[1]' <<<"\"$prever\"")  # "
        pv3=$(jq -r 'split(".")[2]' <<<"\"$prever\"")  # "
        pv4=$(jq -r 'split(".")[3]' <<<"\"$prever\"")  # "
        if test "${pv4}" == "null"; then pv4=0; fi
        echo "prever:${pv1}.${pv2}.${pv3}.${pv4}"

        v1=$(jq -r 'split(".")[0]' <<<"\"$VER\"")  # "
        v2=$(jq -r 'split(".")[1]' <<<"\"$VER\"")  # "
        v3=$(jq -r 'split(".")[2]' <<<"\"$VER\"")  # "
        v4=$(jq -r 'split(".")[3]' <<<"\"$VER\"")  # "

        echo "v4："
        if test "${v4}" == "null"; then
            echo "Is not hotfix"
            v4=0
            ISHOTFIX="false"
        fi
        echo "VER:${v1}.${v2}.${v3}.${v4}"

        NEWER="true"
        if test "$v1" -lt "$pv1"; then
            echo "Check 1"
            NEWER="false"
        fi

        if test "$v2" -lt "$pv2"; then
            echo "Check 2"
            NEWER="false"
        fi

        if test "$v3" -lt "$pv3"; then
            echo "Check 3"
            NEWER="false"
        fi

        if test "$v4" -lt "$pv4"; then
            echo "Check 4"
            NEWER="false"
        fi

        if test "${NEWER}" == "true" && test "${CHKTMP}" == "false"; then
            echo "A Newer version"
            UPDATE_LATEST_CONFIG="true"
        fi

    else
        echo "NO LATEST CONFIG"
        # 不存在，表示是最新的
        UPDATE_LATEST_CONFIG="true"
    fi

    # 如是最新的，更新LATEST
    echo "UPDATE_LATEST_CONFIG:"
    echo ${UPDATE_LATEST_CONFIG}

    if test "${UPDATE_LATEST_CONFIG}" == "true"; then
        echo "UPDATE LATEST"
        CONFIG_LATEST="{\"VER\":\"$VER\",\"cfg\":$cfg,\"vol\":$vol}"
        echo $CONFIG_LATEST
        curl --request PUT --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/variables/${LATEST_VAR}" --form "value=${CONFIG_LATEST}"
    fi

    # 將prever，寫入CFG_VERSION_RECORD

    if test "${CHKTMP}" == "false"; then
        # 不存在，新增上去
        echo "not exsit"
        CFG_VERSION_RECORD=$(jq --arg key "$prever" --argjson value1 "$cfg" --argjson value2 "$vol" '. * {($key):{vol:$value2,cfg:$value1}}' <<<$CFG_VERSION_RECORD)
    else
        # 存在，更新
        echo "exsit"
        CFG_VERSION_RECORD=$(jq --arg key "$prever" --argjson value "$cfg" '.[$key].cfg=$value' <<<$CFG_VERSION_RECORD)
        CFG_VERSION_RECORD=$(jq --arg key "$prever" --argjson value "$vol" '.[$key].vol=$value' <<<$CFG_VERSION_RECORD)
    fi

    echo "CFG_VERSION_RECORD:"
    echo $CFG_VERSION_RECORD

    curl --request PUT --header "PRIVATE-TOKEN:${GITLAB_KEY}" "${GITLAB_URL}/api/v4/projects/${CI_PROJECT_ID}/variables/${RECORD_VAR}" --form "value=${CFG_VERSION_RECORD}"

    # 如不是hotfix，採用LATEST更新CONFIG
    ConfigCfg=""
    ConfigVol=""

    if test "${ISHOTFIX}" == "true"; then
        echo "hotfix"
        # 如是hotfix，只抓前三版本號，找RECORD的CONFIG
        ConfigCfg=$(jq --arg key "${v1}.${v2}.${v3}" '.[$key].cfg' <<<$CFG_VERSION_RECORD)
        ConfigVol=$(jq --arg key "${v1}.${v2}.${v3}" '.[$key].vol' <<<$CFG_VERSION_RECORD)
    else
        echo "not hotfix"
        # 如不是hotfix，找LATEST，更新CONFIG
        ConfigCfg=$(jq '.cfg' <<<$CONFIG_LATEST)
        ConfigVol=$(jq '.vol' <<<$CONFIG_LATEST)
    fi

    echo "-------------------------------------"
    echo $ConfigCfg
    echo "-------------------------------------"
    echo $ConfigVol
    echo "-------------------------------------"

    # 如是hotfix，抓前三版本號，找RECORD的CONFIG

    pod_upgrade_body=$(jq '.annotations."cattle.io/timestamp"=$newVal' --arg newVal ${CI_JOB_TIMESTAMP} <<<"$pod_upgrade_body")
    pod_upgrade_body=$(jq '.containers[].image=$newVal' --arg newVal ${HARBOR_URL}/${HARBOR_PROJECT}/${BUILD_IMAGE_NAME}:${VER} <<<"$pod_upgrade_body")
    pod_upgrade_body=$(jq '.volumes=$newVal' --argjson newVal "${ConfigCfg}" <<<"$pod_upgrade_body")
    pod_upgrade_body=$(jq '.containers[].volumeMounts=$newVal' --argjson newVal "${ConfigVol}" <<<"$pod_upgrade_body")

    echo "${pod_upgrade_body}" >json.txt
    curl -H "Authorization:${K8S_KEY}" -H "Content-Type:application/json" -d "@json.txt" -X PUT ${K8S_API}
}
