package com.wistron.wcd.springbootcicd.service;

import com.wistron.wcd.springbootcicd.model.User;

public interface AuthService {
    User register(User userToAdd);
    String login(String username, String password);
    String refresh(String oldToken);
}
