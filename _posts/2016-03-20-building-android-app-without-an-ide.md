---
layout: post
title: Building Android App Without an IDE
category: dev
---

To build an **Android app**, the recommended tool is [Android Studio](http://developer.android.com/sdk/index.html). But I decided to do it without Android Studio nor Eclipse. I did this, to understand how Android app works and because I prefer command line over heavy IDEs. I have to admit though, that you will need an IDE to build a serious app. In this article, I will walk through how to build a simple Android App **from command line**. The app will have **proguard** enabled, and use **JNI** feature.

This tutorial is tested only in Ubuntu 14.04 LTS x86_64.

<!--more-->

# 1. Install tools

## 1.1. Requirements

**JDK** and **Ant** are required.

```
sudo apt-get install openjdk-7-jdk ant
```

If your system is 64-bit Ubuntu, install these:

```
sudo apt-get install lib32z-dev lib32stdc++6
```

## 1.2. Download Android SDK

From [official download page](http://developer.android.com/sdk/index.html), download **"SDK Tools Only"** version. Then uncompress the file. Then add `<uncompressed_dir>/tools/` and `<uncompressed_dir>/platform-tools/` to your `PATH`.

## 1.3. Install Android SDK Packages

Android SDK itself is not enough to build an app. You have to install following additional SDK elements using SDK manager.

- tools
- platform-tools
- build-tools (latest version)
- SDK platform (API version you want to use)

First query available packages with following command.

```
android list sdk --no-ui --all --extended
```

Then install(update) the tools.

```
android update sdk --no-ui --all --filter tools,platform-tools,build-tools-23.0.2,android-23
```

# 2. Building an App

## 2.1. Create an Empty Android Project

First you check which targets (API version) are available using this command

```
$ android list targets
```

Then create an empty Android project

```
android create project \
	--target <target id> \
	--name <app name> \
	--path <project root> \
	--activity <default activity name> \
	--package <package name>
```

For example,

```
android create project --target 1 --name HelloApp --path ./helloapp \
	--activity MainActivity --package com.example.helloapp
```

Then initial files will be created under `helloapp` directory.

## 2.2. Build the app

Now auto-generate `build.xml`.

```
cd helloapp
android update project --path .
```

Then build the app using Ant.

```
ant release
```

The app will be created at `bin/HelloApp-release-unsigned.apk`.

You can clean the build using

```
ant clean
```

## 2.3. Sign the app

Only signed app can be installed in an Android device. You can sign an apk with your own keystore. If you don't have a keystore, here's how to make one.

```
keytool -genkey -v \
  -keystore mykey.keystore \
  -alias mykeyname \
  -keyalg RSA -keysize 2048 \
  -validity 365
```

It will ask you a **keystore password**, your information (optional) and the **alias password** you provided. (A *keystore* can hold multiple entries and each entry is called *alias*. This is why it asks for two passwords.) After it's done, `mykey.keystore` file will be created. Keep this keystore file somewhere safe.

Then add these lines to `ant.properties` file.

```
key.store=<keystore file location>
key.alias=<alias name>
key.store.password=<keystore password>
key.alias.password=<alias password>
```

Now  `ant release` command will sign the app. The signed app will be produced as `bin/HelloApp-release.apk`.

## 2.4. Install and run the app

Move `bin/HelloApp-release.apk` to your Android machine or a virtual device, then install it. It may have to enable "Allow installation of apps from unknown source" option. Enjoy your hello world!

# 3. Enabling ProGuard

ProGuard is an Android obfuscation & minification tool. If an app is filtered through ProGuard, then method names and class names will change into something like a, b, c, .... It makes reverse engineers' life difficult.

Turning on ProGuard is simple. Uncomment following line in `project.properties`

```
proguard.config=${sdk.dir}/tools/proguard/proguard-android.txt:proguard-project.txt
```

That's it. Now `ant release` will apply ProGuard.

# 4. Using JNI

JNI(Java Native Interface) allows calling native programs directly from Java code. For example, you can call C function just like a Java method. You can use JNI feature using Android NDK(Native Development Kit).

## 4.1. Download NDK

Download NDK [here](http://developer.android.com/ndk/downloads/index.html) and uncompress it. Add the uncompressed directory to your `PATH`.

## 4.2. Write code and configs

Write this into `jni/Android.mk`

```
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE    := hello-jni
LOCAL_SRC_FILES := hello-jni.c
include $(BUILD_SHARED_LIBRARY)
```

Write this into `jni/Application.mk`

```
APP_ABI := all
```

Write this into `jni/hello-jni.c`

```c
#include <string.h>
#include <jni.h>

jstring
Java_com_example_myapp_HelloActivity_helloJni(JNIEnv* env, jobject thiz)
{
    return (*env)->NewStringUTF(env, "Hello!!");
}
```

Modify `src/com/example/helloapp/MainActivity.java`

```java
// ...
public class MainActivity extends Activity {
	static {
		System.loadLibrary("hello-jni");
	}
	public native String helloJni();
	// ...
}
```

## 4.3. Build native library

Then at the project root,

```
ndk-build
```

Shared library (\*.so) files for each architecture should be created at `libs/`. Then package the app.

```
ant release
```


