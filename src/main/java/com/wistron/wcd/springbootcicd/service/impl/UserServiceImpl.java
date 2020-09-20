package com.wistron.wcd.springbootcicd.service.impl;

import com.github.pagehelper.PageHelper;
import com.wistron.wcd.springbootcicd.model.User;
import com.wistron.wcd.springbootcicd.repository.UserMapper;
import com.wistron.wcd.springbootcicd.service.UserService;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.List;

@Service("userService")
public class UserServiceImpl implements UserService {
    // 注入mapper类
    @Resource
    private UserMapper userMapper;

    @Cacheable(value = "user", key= "#userId")
    @Override
    public User getUserById(long userId) {
        return userMapper.selectByPrimaryKey(userId);
    }
    @Override
    public List<User> listUser(int page, int pageSize) {
        List<User> result = null;
        try {
            // 调用pagehelper分页，采用starPage方式。starPage应放在Mapper查询函数之前
            PageHelper.startPage(page, pageSize); //每页的大小为pageSize，查询第page页的结果
            PageHelper.orderBy("id ASC "); //进行分页结果的排序
            result = userMapper.selectUser();
        } catch (Exception e) {
            e.printStackTrace();
        }

        return result;
    }

    @CacheEvict(value = "user", key= "#userId")
    @Override
    public User updateUserNickname(long userId, String nickname) {
        User user = userMapper.selectByPrimaryKey(userId);
        user.setNickname(nickname);
        userMapper.updateByPrimaryKey(user);
        return user;
    }
}
