# java-server-app-blue-green-node
Java 服务器应用蓝绿节点 Shell 脚本

> 此处的蓝绿节点，指的是蓝是新节点（带有新功能），绿是老节点，在蓝节点上线前，线上运行的是绿节点，在蓝节点部署后，自动将流量切换到蓝节点（蓝节点上线）后，绿节点开始下线，直到 kill，这样流量就会无缝的切换到蓝节点，用户理论上并无感知。算是一种蓝绿节点部署实现思路，用以实现线上环境后端应用无缝切换上线新功能。目前仅支持以 Nacos 为注册中心的服务。上线准备中需要为服务提供一个 deregister restful 接口供蓝绿脚本调用（以下有示例代码）。 

## 特性 Features

- [x] 无缝切换蓝绿服务
- [x] 随机应用端口部署
- [x] 探测新节点健康状态
- [x] 同一个应用支持一次部署多个节点
- [x] 支持额外端口

## 部署 Deploy

为要参与蓝绿节点部署的应用准备以下接口供服务主动下线

```java
package com.godcheese.example;

import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.client.serviceregistry.AbstractAutoServiceRegistration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.annotation.Resource;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
* nacos
*
* @author godcheese [godcheese@outlook.com]
* @date 2022-12-22
  */
  @Slf4j
  @RestController
  @RequiredArgsConstructor
  public class NacosController {

  @Resource
  private AbstractAutoServiceRegistration<?> abstractAutoServiceRegistration;

  /**
    * nacos 服务主动下线
    *
    * @param request HttpServletRequest
    * @param response HttpServletResponse
    * @return String
    * @author godcheese [godcheese@outlook.com]
    * @date 2022-12-22
      */
      @GetMapping(value = "/nacos/deregister")
      public String deregister(HttpServletRequest request, HttpServletResponse response) {
      boolean isLocalhost = "localhost".equalsIgnoreCase(request.getServerName());
      // 需要与 node_guard.sh 中 deregister_authorization="example_password" 的 example_password 一致才能正常工作
      boolean isAuthorization = "example_password".equals(request.getHeader("Authorization"));
      if (!isLocalhost || !isAuthorization) {
      response.setStatus(HttpStatus.UNAUTHORIZED.value());
      return "error";
      }
      log.info("deregister from nacos start");
      try {
      abstractAutoServiceRegistration.destroy();
      } catch (Exception e) {
      log.error("deregister from nacos error", e);
      return "error";
      }
      log.info("deregister from nacos end");
      return "success";
      }

}
```

## 运行 Run

调用方式，如：
```shell
bash deploy.sh "example" "example.jar" "dev" 8000 8999 2 1 20 256k 1024m 1024m
# example 服务名
# example.jar 运行的程序 jar
# dev active profile
# 8000 随机端口区间-start
# 8999 随机端口区间-end
# 2 端口数量, 根据节点数量 * 2
# 1 启动的新节点数量
# 20 节点守护时探测新节点的次数，每次间隔 10s
# 256k JVM Xss
# 1024m JVM Xms
# 1024m JVM Xmx
```

## 反馈 Feedback

[Issues](https://github.com/godcheese/java-server-app-blue-green-node/issues)

## 捐赠 Donation

如果此项目对你有所帮助，不妨请我喝咖啡。
If you find this project useful, you can buy us a cup of coffee.

[Paypal Me](https://www.paypal.me/godcheese)
