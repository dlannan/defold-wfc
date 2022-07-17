# Wave Function Collapse for Defold

This project is a conversion of the CSharp source code from the the amazing Wave Function Collapse project here:

https://github.com/mxgmn/WaveFunctionCollapse

I have redeveloped the CSharp into Lua + a native extension (for std_image operations). 
Heres some simple examples of the app in action:

![wave-function-collapse-app-2022-07-17_21-27](https://user-images.githubusercontent.com/3954182/179398212-3de9c6c3-8d9f-4b94-8c95-86d1019e9ce2.png)

![wave-function-collapse-app-2022-07-17_21-28](https://user-images.githubusercontent.com/3954182/179398218-e1395f58-6309-4d0a-83d9-9cefb8af29cd.png)

![wave-function-collapse-app-2022-07-17_21-29](https://user-images.githubusercontent.com/3954182/179398227-853eb6f6-c7b9-495c-8aeb-63074088f85b.png)

![wave-function-collapse-app-2022-07-17_21-31](https://user-images.githubusercontent.com/3954182/179398238-655a898a-555e-46ff-b9c5-912d97a01e0f.png)

![wave-function-collapse-app-2022-07-17_21-32](https://user-images.githubusercontent.com/3954182/179398241-124a53f6-30fc-4aba-962f-6b494b1bce2a.png)

Features:

- Most of the parameters for running both models. Overlapped Model (single texture source) and Simple Tiled Model (folder + data.xml + source tiles)
- All samples in sample.xml are in a drop down that can be selected and then "Run Sample" executes them. Generally they output 1 or more png files to the output folder.
- While executing the Run Sample button will remain red. Some samples can run for a long time if the parameters result in more complex operations.
- All pngs in the output folder are removed upon startup. If you want to save your generated pngs, copy them out of the output folder!

Todos:
- There is currently no gui setting for choosing a seed value. I will add this.
- The sample png source files are all under the CC license. See below. This will change, as all samples will be removed and replaced with free versions.
- General cleanup and perf improvements.
- Attempt to get it to work in html5 - will be a bit slow, but with cloud based url sources, could be very interesting.

---
