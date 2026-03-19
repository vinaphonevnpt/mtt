#ifndef __NEWS_AND_SENTIMENT_MQH__
#define __NEWS_AND_SENTIMENT_MQH__

//==============================================================
// NewsAndSentiment.mqh (FINAL CLEAN)
// - KHÔNG định nghĩa lại GetHourNow / GetMinuteNow
//==============================================================

#include "ConfigurationInputs.mqh"
#include "LoggingAndTimeUtils.mqh"

//==============================================================
// PARSE TIME "HH:MM"
//==============================================================
bool ParseTimeHM(string s, int &hour, int &min)
{
   string parts[];
   int n = StringSplit(s, ':', parts);
   if(n != 2) return false;

   hour = (int)StringToInteger(parts[0]);
   min  = (int)StringToInteger(parts[1]);

   return true;
}

//==============================================================
// HIGH IMPACT NEWS (MANUAL)
//==============================================================
bool IsHighImpactNewsSoon(string &reason)
{
   if(!InpBlockAroundNews)
      return false;

   if(StringLen(InpHighImpactNewsTimes) == 0)
      return false;

   string arr[];
   int count = StringSplit(InpHighImpactNewsTimes, ';', arr);

   int nowMin = GetHourNow()*60 + GetMinuteNow();

   for(int i=0;i<count;i++)
   {
      int h,m;
      if(!ParseTimeHM(arr[i], h, m))
         continue;

      int newsMin = h*60 + m;

      if(MathAbs(nowMin - newsMin) <= InpNewsBlockBefore_Min)
      {
         reason = "Tin tức mạnh sắp ra";
         return true;
      }

      if(MathAbs(nowMin - newsMin) <= InpNewsBlockAfter_Min)
      {
         reason = "Sau tin tức mạnh";
         return true;
      }
   }

   return false;
}

//==============================================================
// SENTIMENT FILE
//==============================================================
double GetXAUUSDSentimentScore()
{
   if(!InpUseXSentiment)
      return 0.0;

   int handle = FileOpen(InpSentimentFilePath, FILE_READ|FILE_TXT|FILE_ANSI);

   if(handle == INVALID_HANDLE)
   {
      Log("Không đọc được file sentiment");
      return 0.0;
   }

   string line = FileReadString(handle);
   FileClose(handle);

   return StringToDouble(line);
}

//==============================================================
// SENTIMENT FILTER
//==============================================================
bool PassSentimentFilter(bool isBuy, string &reason)
{
   if(!InpUseXSentiment)
      return true;

   double sentiment = GetXAUUSDSentimentScore();

   if(isBuy && sentiment < InpBearishThreshold)
   {
      reason = "Sentiment bearish";
      return false;
   }

   if(!isBuy && sentiment > -InpBearishThreshold)
   {
      reason = "Sentiment bullish";
      return false;
   }

   return true;
}

//==============================================================
// DYNAMIC NEWS (PLACEHOLDER)
//==============================================================
bool DynamicNewsBlockNow(string &reason)
{
   return false;
}

//==============================================================
// SMART NEWS BLOCK
//==============================================================
bool SmartNewsBlock(string &reason)
{
   if(IsHighImpactNewsSoon(reason))
      return true;

   if(DynamicNewsBlockNow(reason))
      return true;

   return false;
}

//==============================================================
// SMART LOT ADJUST
//==============================================================
double SmartNewsAdjustLot(double lot)
{
   string reason;

   if(IsHighImpactNewsSoon(reason))
      return lot * 0.5;

   if(InpUseXSentiment)
   {
      double s = GetXAUUSDSentimentScore();

      if(MathAbs(s) < 0.1)
         return lot * 0.8;
   }

   return lot;
}

#endif