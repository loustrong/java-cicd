package com.wistron.wcd.springbootcicd.repository;

import com.wistron.wcd.springbootcicd.model.User;

import java.util.List;

public interface UserMapper {
    int deleteByPrimaryKey(Long id);

    int insert(User record);

    int insertSelective(User record);

    User selectByPrimaryKey(Long id);

    int updateByPrimaryKeySelective(User record);

    int updateByPrimaryKey(User record);
    // 列出用户，对应xml映射文件元素的ID
    List<User> selectUser();
}