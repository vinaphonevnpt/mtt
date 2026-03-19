#ifndef __TREND_AND_MTF_ANALYSIS_MQH__
#define __TREND_AND_MTF_ANALYSIS_MQH__

//==============================================================
// TrendAndMTFAnalysis.mqh
// Phân tích xu hướng + MTF + pullback + trend context
// Chuẩn MQL5 - FIX toàn bộ lỗi iMA, duplicate, enum
//==============================================================

#include "ConfigurationInputs.mqh"
#include "IndicatorCache.mqh"

//==============================================================
// EMA HANDLE MTF
//==============================================================
int hEMA_TF1_21 = INVALID_HANDLE;
int hEMA_TF1_50 = INVALID_HANDLE;
int hEMA_TF2_21 = INVALID_HANDLE;
int hEMA_TF2_50 = INVALID_HANDLE;

//==============================================================
// INIT MTF EMA
//==============================================================
bool InitMTFTrend()
{
   hEMA_TF1_21 = iMA(_Symbol, InpTrendTF1, 21, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_TF1_50 = iMA(_Symbol, InpTrendTF1, 50, 0, MODE_EMA, PRICE_CLOSE);

   hEMA_TF2_21 = iMA(_Symbol, InpTrendTF2, 21, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_TF2_50 = iMA(_Symbol, InpTrendTF2, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(hEMA_TF1_21 == INVALID_HANDLE || hEMA_TF1_50 == INVALID_HANDLE ||
      hEMA_TF2_21 == INVALID_HANDLE || hEMA_TF2_50 == INVALID_HANDLE)
   {
      Print("❌ Init MTF EMA failed");
      return false;
   }

   return true;
}

//==============================================================
// GET BUFFER
//==============================================================
double GetBuffer(int handle, int shift=0)
{
   double val[];
   if(CopyBuffer(handle, 0, shift, 1, val) <= 0)
      return 0.0;

   return val[0];
}

//==============================================================
// EMA TREND DIR (TF hiện tại)
//==============================================================
int GetEMATrendDir(int shift=0)
{
   double ema21 = GetEMA21(shift);
   double ema50 = GetEMA50(shift);

   if(ema21 > ema50) return 1;
   if(ema21 < ema50) return -1;
   return 0;
}

//==============================================================
// EMA TREND MTF
//==============================================================
int GetMTFTrendTF1()
{
   double ema21 = GetBuffer(hEMA_TF1_21);
   double ema50 = GetBuffer(hEMA_TF1_50);

   if(ema21 > ema50) return 1;
   if(ema21 < ema50) return -1;
   return 0;
}

int GetMTFTrendTF2()
{
   double ema21 = GetBuffer(hEMA_TF2_21);
   double ema50 = GetBuffer(hEMA_TF2_50);

   if(ema21 > ema50) return 1;
   if(ema21 < ema50) return -1;
   return 0;
}

//==============================================================
// MTF ALIGN
//==============================================================
bool IsMTFAligned(bool isBuy)
{
   if(!InpRequireMTFTrendAlign)
      return true;

   int t1 = GetMTFTrendTF1();
   int t2 = GetMTFTrendTF2();

   if(isBuy)
      return (t1 == 1 && t2 == 1);
   else
      return (t1 == -1 && t2 == -1);
}

//==============================================================
// ENHANCED TREND FILTER
//==============================================================
bool EnhancedTrendDirectionFilter(bool isBuy)
{
   if(!InpUseEnhancedTrendDirection)
      return true;

   double ema_now = GetEMA21(0);
   double ema_prev = GetEMA21(3);

   double slope = MathAbs(ema_now - ema_prev);

   if(slope < InpTrendSlopeMinPrice)
      return false;

   int dir = GetEMATrendDir();

   if(isBuy && dir != 1) return false;
   if(!isBuy && dir != -1) return false;

   return true;
}

//==============================================================
// ANTI CHASE FILTER
//==============================================================
bool AntiChaseFilter(bool isBuy)
{
   if(!InpUseAntiChaseFilter)
      return true;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ema = GetEMA21();

   double distance = MathAbs(price - ema);

   if(distance > GetATR14() * 1.2)
      return false;

   return true;
}

//==============================================================
// ANTI EXHAUSTION FILTER
//==============================================================
bool AntiExhaustionFilter(bool isBuy)
{
   if(!InpUseAntiExhaustionFilter)
      return true;

   double rsi = GetRSI14();

   if(isBuy && rsi > 70) return false;
   if(!isBuy && rsi < 30) return false;

   return true;
}

//==============================================================
// TREND CONTEXT
//==============================================================
bool IsTrendFollowContext(bool isBuy)
{
   int trend = GetEMATrendDir();

   if(isBuy && trend == 1) return true;
   if(!isBuy && trend == -1) return true;

   return false;
}

//==============================================================
// PULLBACK LOGIC (simple)
//==============================================================
bool IsPullbackEntry(bool isBuy)
{
   double rsi = GetRSI14();

   if(isBuy)
      return (rsi < 50);
   else
      return (rsi > 50);
}

#endif