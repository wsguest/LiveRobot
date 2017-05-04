// TemplateMatch.cpp : 定义控制台应用程序的入口点。
//

#include "stdafx.h"

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