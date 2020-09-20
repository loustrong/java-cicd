package com.wistron.wcd.springbootcicd.controller;

import com.wistron.wcd.springbootcicd.common.util.Result;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.RequestMapping;

import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.slf4j.LoggerFactory;

@RestController
@RequestMapping("/hello")
public class HelloController {

    @RequestMapping(value="/hello1", method=RequestMethod.GET)
    public String hello1() {

        return "Hello1!";
    }

    @RequestMapping(value="/hello2", method=RequestMethod.GET)
    public String hello2() {

        return "Hello2!";
    }

    @RequestMapping(value="/hello3", method=RequestMethod.GET)
    public String hello3() {

        return "Hello3!";
    }

    @SuppressWarnings("unused")
    private static final org.slf4j.Logger log = LoggerFactory.getLogger(HelloController.class);

    // 当前环境配置名称
    @Value("${profile.name}") //读取当前环境配置名称
    private String profileName;

    @RequestMapping(value="/helloProfile", method = RequestMethod.GET, produces="application/json")
    public String hello() {

        log.trace("trace 信息");
        log.debug("debug 信息");
        log.info("info 信息");
        log.warn("warn 信息");
        log.error("error 信息");
        return "当前环境：" + profileName;
    }
    @Autowired
    JdbcTemplate jdbcTemplate;

    @RequestMapping(value="/hello", method=RequestMethod.GET)
    public String index() {

        String sql = "SELECT mobile FROM user WHERE id = ?";

        // 通过jdbcTemplate查询数据库
        String mobile = (String)jdbcTemplate.queryForObject(
                sql, new Object[] { 1 }, String.class);

        return "Hello " + mobile;
    }
    @RequestMapping(value="/helloResult", method = RequestMethod.GET, produces="application/json")
    public ResponseEntity<Result> hello(@RequestParam(value="bad", required=false, defaultValue="false") boolean bad) {

        // 结果封装类对象
        Result res = new Result(200, "ok");

        if(bad) {
            res.setStatus(400);
            res.setMessage("Bad request");

            // ResponseEntity是响应实体泛型，通过它可以设置http响应的状态值，此处返回400
            return new ResponseEntity<Result>(res, HttpStatus.BAD_REQUEST);
        }

        // 把结果数据放进封装类
        res.putData("words", "Hello world!");

        // ResponseEntity是响应实体泛型，通过它可以设置http响应的状态值，此处返回200
        return ResponseEntity.ok(res);
    }
}