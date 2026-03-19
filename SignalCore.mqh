#ifndef __SIGNAL_CORE_MQH__
#define __SIGNAL_CORE_MQH__

#include "ConfigurationInputs.mqh"
#include "AdaptiveFrequencyEngine.mqh"
#include "IndicatorCache.mqh"
#include "TrendAndMTFAnalysis.mqh"
#include "MLAndONNX.mqh"

//==============================================================
double GetADXValue_SC()
{
   int handle = iADX(_Symbol,_Period,InpADXPeriod);
   if(handle==INVALID_HANDLE) return 0;

   double buf[];
   if(CopyBuffer(handle,0,0,1,buf)<=0) return 0;

   return buf[0];
}

//==============================================================
bool ScalpingProGate(bool isBuy,string &reason)
{
   reason="";

   double rsi    = GetRSI14();
   double adx    = GetADXValue_SC();
   double spread = (double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   int    trend  = GetTrendDirection();
   double ml     = 0.5;

   //================ FREQ =================
   if(!FrequencyAdaptiveGate(reason))
   {
      reason += " | Spread hiện=" + DoubleToString(spread,1);
      return false;
   }

   //================ TREND =================
   if(InpRequireMTFTrendAlign)
   {
      if(isBuy && trend < 0)
      {
         reason = "Trend SELL | trend=" + IntegerToString(trend);
         return false;
      }

      if(!isBuy && trend > 0)
      {
         reason = "Trend BUY | trend=" + IntegerToString(trend);
         return false;
      }
   }

   //================ RSI =================
   if(InpUseRSI_OBOS_Filter)
   {
      if(isBuy && rsi < 30)
      {
         reason = "RSI thấp | cần>30 | hiện=" + DoubleToString(rsi,1);
         return false;
      }

      if(!isBuy && rsi > 70)
      {
         reason = "RSI cao | cần<70 | hiện=" + DoubleToString(rsi,1);
         return false;
      }
   }

   //================ ADX =================
   if(adx < 20)
   {
      reason = "ADX yếu | cần>20 | hiện=" + DoubleToString(adx,1);
      return false;
   }

   //================ ML =================
   if(ml < InpMLScoreThreshold_Buy)
   {
      reason = "ML thấp | cần>" + DoubleToString(InpMLScoreThreshold_Buy,2) +
               " | hiện=" + DoubleToString(ml,2);
      return false;
   }

   return true;
}

#endif