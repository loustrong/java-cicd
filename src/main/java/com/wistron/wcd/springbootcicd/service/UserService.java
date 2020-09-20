package com.wistron.wcd.springbootcicd.service;

import com.wistron.wcd.springbootcicd.model.User;

import java.util.List;

public interface UserService {
    public User getUserById(long userId);
    public List<User> listUser(int page, int pageSize);
    public User updateUserNickname(long userId, String nickname);
}
