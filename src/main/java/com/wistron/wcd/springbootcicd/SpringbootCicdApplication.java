package com.wistron.wcd.springbootcicd;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@MapperScan("com.wistron.wcd.springbootcicd.repository")
public class SpringbootCicdApplication {

	public static void main(String[] args) {
		SpringApplication.run(SpringbootCicdApplication.class, args);
	}

}
