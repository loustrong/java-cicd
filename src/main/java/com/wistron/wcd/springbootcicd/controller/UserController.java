package com.wistron.wcd.springbootcicd.controller;

import com.github.pagehelper.PageInfo;
import com.wistron.wcd.springbootcicd.common.util.Result;
import com.wistron.wcd.springbootcicd.model.User;
import com.wistron.wcd.springbootcicd.service.UserService;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.List;

@RestController
@EnableAutoConfiguration
@RequestMapping("/user")
public class UserController {
    // 注入mapper类
    @Resource
    private UserService userService;

    // 注入RedisTemplate
    @Resource
    private RedisTemplate<String, Object> redis;

    @RequestMapping(value="{id}", method= RequestMethod.GET, produces="application/json")
    public User getUser(@PathVariable long id) throws Exception {
        User user = this.userService.getUserById(id);
        return user;
    }
    @RequestMapping(value="", method = RequestMethod.GET, produces="application/json")
    public PageInfo<User> listUser(
            @RequestParam(value="page", required=false, defaultValue="1") int page,
            @RequestParam(value="page-size", required=false, defaultValue="5") int pageSize){


        List<User> result = userService.listUser(page, pageSize);
        // PageInfo包装结果，返回更多分页相关信息
        PageInfo<User> pi = new PageInfo<User>(result);

        return pi;
    }

    // 修改用户信息，测试删除缓存
    @RequestMapping(value = "/{id}/change-nick", method = RequestMethod.POST, produces="application/json")
    public User changeNickname(@PathVariable long id) throws Exception{

        String nick = "abc-" + Math.random();
        User user = this.userService.updateUserNickname(id, nick);

        return user;
    }

    // 使用RedisTemplate访问redis服务器
    @RequestMapping(value="/redis", method=RequestMethod.GET, produces="application/json")
    public String redis() throws Exception {

        // 设置键"project-name"，值"qikegu-springboot-redis-demo"
        redis.opsForValue().set("project-name", "tom-springboot-redis-demo");
        String value = (String) redis.opsForValue().get("project-name");
        return value;
    }

}
