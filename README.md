# Android packer-ng-plugin渠道打包辅助工具

---

## 前言

在 Android 7.0 Nougat 中引入了全新的 APK Signature Scheme v2签名方式，为了加快打包速度，我们这里使用了[packer-ng-plugin](https://github.com/mcxiaoke/packer-ng-plugin)这个打包工具。

## 出现的问题

* 360加固后重新签名渠道打包未生效，后台统计不到渠道来源（其他数据不影响）

## 分析原因

因为360加固后需要重新签名，借助360官方提供的签名工具qihoo apk signer，是采用的7.0以前的v1签名，这时再通过packer-ng-plugin打渠道包，是无法成功往apk写入渠道号的。这时我们就必须借助Android SDK提供的apksigner工具对已经打包好的apk进行v2签名。

## 使用官方自带工具进行签名

Android官方文档已经对[apksigner](https://developer.android.com/studio/command-line/apksigner.html#options-sign-general)的使用有比较详细的解释。以Mac/Linux平台为例（Windows类似），tools工具就在$ANDROID_SDK_HOME/build-tools目录下 **（build-tools版本需要选择25以上，因为v2签名Android 7.0 以上才支持，下面使用27.0.2版本来执行）**，因为下面说说实际的操作步骤：

1. zipalign

    zip对齐，因为APK包的本质是一个zip压缩文档，经过边界对齐方式优化能使包内未压缩的数据有序的排列，从而减少应用程序运行时的内存消耗 ，通过空间换时间的方式提高执行效率（zipalign后的apk包体积增大了100KB左右）。
    打开Terminal，把目录切换到SDK/build-tools/版本号/目录下（例如我这边的目录是/opt/android/sdk/build-tools/27.0.2/），执行：
    
    ```SHELL
    cd /opt/android/sdk/build-tools/27.0.2/
    ./zipalign -v -p 4 input.apk output.apk
    ```

    zipalign命令选项不多：
    -f : 输出文件覆盖源文件
    -v : 详细的输出log
    -p : outfile.zip should use the same page alignment for all shared object files within infile.zip
    -c : 检查当前APK是否已经执行过Align优化。
    另外上面的数字4是代表按照4字节（32位）边界对齐。

2. apksigner

    这个工具位于SDK目录的build-tools目录下。**必须说明的是，v2签名方式时在Android7.0后才推出的，所以只有版本>25的SDK\build-tools\中才能找到apksigner**。
    打开Terminal，把目录切换到SDK/build-tools/版本号/目录下（例如我这边的目录是/opt/android/sdk/build-tools/27.0.2/），执行：

    ```SHELL
    ./apksigner sign  --ks key.jks  --ks-key-alias releasekey  --ks-pass pass:pp123456  --key-pass pass:pp123456  --out output.apk  input.apk
    ```

    参数说明：

    ```SHELL
    java -jar apksigner.jar sign           //执行签名操作
    --ks 你的jks路径                                 //jks签名证书路径
    --ks-key-alias 你的alias           //生成jks时指定的alias
    --ks-pass pass:你的密码          //KeyStore密码
    --key-pass pass:你的密码   //签署者的密码，即生成jks时指定alias对应的密码
    --out output.apk                         //输出路径
    input.apk                                     //被签名的apk
    ```

    签名完成之后，可以验证是否签名成功

    ```SHELL
    ./apksigner verify -v input.apk
    ```

## 使用packer-ng-plugin命令打渠道包

因为代码里面已经配置了使用packer-ng-plugin打包，所以这里需要使用packer-ng-plugin的命令在已有的包上增加渠道信息，不可以通过build的方式重新打包

```
java -jar packer-ng-2.0.0.jar generate --channels=@channels.txt --output=build/archives app.apk
```

参数说明：

```
channels.txt - 替换成你的渠道列表文件的实际路径
build/archives - 替换成你指定的渠道包的输出路径
app.apk - 替换成你要打渠道包的APK文件的实际路径
```

验证渠道信息是否已经添加

```SHELL
java -jar packer-ng-2.0.0.jar verify app.apk
```

## 自动化脚本处理加固后的包

注：这里的脚本是针对加固后的包进行签名和渠道添加，不需要加固的市场仍然可以直接通过下面的命令打包
```SHELL
./gradlew clean apkRelease
```

其实就是对上面的命令进行整合，通过文件等签名信息通过配置文件的形式修改参数

配置文件参数示例（具体配置根据实际情况来）：
```SHELL
#加固后的apk文件路径
INPUT_APK_PATH=/data/apks/v1.0.1/360_101_jiagu_sign.apk
#keystore文件路径
KEYSTORE_PATH=/data/project/android/app-android-CreditQuery/app/sign/key_store.jks
#keystore密码，建议加上引号，否则无法读取到特殊符号
KEYSTORE_PASSWORD='f!u@d#a'
#keystore alias名
KEYSTORE_ALIAS=app_alias
#keystore alias密码，建议加上引号，否则无法读取到特殊符号
KEYSTORE_ALIAS_PASSWORD='f!u@d#a'
#渠道列表文件
CHANNELS_FILE_PATH=/data/project/android/app-android-CreditQuery/channels.txt
```

最终文件输出路径就在脚本当前目录的build/output文件夹中

编辑packer.config,配置完参数后

执行下面命令打包

```SHELL
./start.sh
```

如无法执行，请添加可执行权限

```SHELL
sudo chmod a+x start.sh
```

## 感谢

[packer-ng-plugin](https://github.com/mcxiaoke/packer-ng-plugin)
[Android开发之通过apksigner对apk进行v2签名](https://www.jianshu.com/p/e1e2fd05bb62)


