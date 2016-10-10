---
layout: post
title: Writing Video in OSX with OpenCV
category: dev
---

## Tutorial doesn't work!

The [tutorial](http://docs.opencv.org/2.4/doc/tutorials/highgui/video-write/video-write.html) says we can record a webcam video with following code. (which doesn't work)

```cpp
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/highgui/highgui.hpp>

int main()
{
  VideoCapture capture(0);

  int w = capture.get(CV_CAP_PROP_FRAME_WIDTH);
  int h = capture.get(CV_CAP_PROP_FRAME_HEIGHT);
  int fps = 30;
  VideoWriter writer("out.mp4", CV_FOURCC('X','2','6','4'), fps, Size(w,h), true);

  Mat frame;
  while (true)
  {
    capture >> frame;
    writer << frame;
    imshow("frame", frame);
    if (waitKey(20) == 27) break;
  }
}
```

It doesn't work on default OpenCV library for OSX. The program runs without error, but produces an empty file. I tried to change the `fourcc` values into `'M','J','P','G'` and change the extension to `.avi` or even set `fourcc` to -1. But all these tries didn't work.

According to a [Stackoverflow Thread](http://stackoverflow.com/questions/4872383/how-to-write-a-video-file-with-opencv) OSX version of OpenCV does not have a working video writer. Ouch! Instead, this thread suggests me another way.

## Saving images and stitching them using ffmpeg

### Save images

First, modify the code a little bit.

```cpp
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <stdio.h>

int main()
{
  VideoCapture capture(0);

  int w = capture.get(CV_CAP_PROP_FRAME_WIDTH);
  int h = capture.get(CV_CAP_PROP_FRAME_HEIGHT);
  int fps = 30;
  VideoWriter writer("out.mp4", CV_FOURCC('X','2','6','4'), fps, Size(w,h), true);

  Mat frame;
  char buf[100];
  int i = 0;
  while (true)
  {
    capture >> frame;
    i ++;
    sprintf(buf, "frames/%03d.jpg", i); // Make sure directory 'frames' exists.
    imwrite(buf, frame);
    imshow("frame", frame);
    if (waitKey(20) == 27) break;
  }
}
```

Then image frames will be saved sequentially. With `ffmpeg`, we can combine these image files into one video file.

### Install ffmpeg

```
brew install ffmpeg
```

H264 codec are automatically installed with this command.

### Run ffmpeg

Finally, combine image files into single video file.

```
ffmpeg -i "%03d.jpg" -c:v libx264 -r 30 out.mp4
```

- `-i` specifies the input file names, in `printf()` format.
- `-c` specifies the codec we will use. This one is H264 codec.
- `-r` specifies the frame rate (FPS).

For details, consult `man ffmpeg`


