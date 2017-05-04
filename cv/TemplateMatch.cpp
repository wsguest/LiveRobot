// TemplateMatch.cpp : 图像模板匹配，依赖opencv。
//

// OpenCV
#include "opencv2/opencv.hpp"
#ifdef _DEBUG

#pragma comment(lib, "opencv_core231d.lib")
#pragma comment(lib, "opencv_imgproc231d.lib")
#pragma comment(lib, "opencv_highgui231d.lib")

#else
#pragma comment(lib, "opencv_core231.lib")
#pragma comment(lib, "opencv_imgproc231.lib")
#pragma comment(lib, "opencv_highgui231.lib")
#endif // _DEBUG
using namespace cv;

float Detect(string strImg, string strTmpl)
{
	Mat img = imread(strImg/*, CV_LOAD_IMAGE_GRAYSCALE*/);
	Mat tmpl = imread(strTmpl/*, CV_LOAD_IMAGE_GRAYSCALE*/);
	if(img.data == NULL 
		|| tmpl.data == NULL
		|| img.rows < tmpl.rows
		|| img.cols < tmpl.cols)
		return FLT_MAX;
	Mat result(img.rows-tmpl.rows+1, img.cols-tmpl.cols+1, CV_32FC1);
	matchTemplate(img, tmpl, result, CV_TM_SQDIFF_NORMED);
	double minValue = FLT_MAX;
	minMaxLoc(result, &minValue);
	return minValue;
}



int _tmain(int argc, _TCHAR* argv[])
{
	if(argc < 2)
		return -1;
	float val = Detect(argv[2], argv[1]);
	if(val > 1.1f || val < -0.1f)
		return -1;
	val = (1.f - val) * 100;
#ifdef _DEBUG
	cout<<val<<endl;
#endif
	return static_cast<int>(val);
}
