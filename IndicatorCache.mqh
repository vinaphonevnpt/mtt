#ifndef __INDICATOR_CACHE_MQH__
#define __INDICATOR_CACHE_MQH__

//==============================================================
// IndicatorCache.mqh
// Cache toàn bộ indicator (ATR, RSI, EMA, ADX, Stochastic)
// Chuẩn MQL5 - Không lỗi compile - Tối ưu hiệu năng
//==============================================================

#include "ConfigurationInputs.mqh"

//==============================================================
// HANDLES
//==============================================================
int hATR = INVALID_HANDLE;
int hRSI = INVALID_HANDLE;
int hEMA21 = INVALID_HANDLE;
int hEMA50 = INVALID_HANDLE;
int hADX = INVALID_HANDLE;
int hStoch = INVALID_HANDLE;

//==============================================================
// INIT
//==============================================================
bool InitIndicatorCache()
{
   // ATR
   hATR = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   if(hATR == INVALID_HANDLE)
   {
      Print("❌ Init ATR failed");
      return false;
   }

   // RSI
   hRSI = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   if(hRSI == INVALID_HANDLE)
   {
      Print("❌ Init RSI failed");
      return false;
   }

   // EMA21
   hEMA21 = iMA(_Symbol, InpTimeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
   if(hEMA21 == INVALID_HANDLE)
   {
      Print("❌ Init EMA21 failed");
      return false;
   }

   // EMA50
   hEMA50 = iMA(_Symbol, InpTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(hEMA50 == INVALID_HANDLE)
   {
      Print("❌ Init EMA50 failed");
      return false;
   }

   // ADX
   hADX = iADX(_Symbol, InpTimeframe, InpADXPeriod);
   if(hADX == INVALID_HANDLE)
   {
      Print("❌ Init ADX failed");
      return false;
   }

   // Stochastic (chỉ tạo khi bật)
   if(InpUseStochFilter)
   {
      hStoch = iStochastic(_Symbol, InpTimeframe,
                           5, 3, 3,
                           MODE_SMA, STO_LOWHIGH);

      if(hStoch == INVALID_HANDLE)
      {
         Print("❌ Init Stochastic failed");
         return false;
      }
   }

   Print("✅ IndicatorCache initialized");
   return true;
}


//==============================================================
// RELEASE
//==============================================================
void ReleaseIndicatorCache()
{
   if(hATR != INVALID_HANDLE)   IndicatorRelease(hATR);
   if(hRSI != INVALID_HANDLE)   IndicatorRelease(hRSI);
   if(hEMA21 != INVALID_HANDLE) IndicatorRelease(hEMA21);
   if(hEMA50 != INVALID_HANDLE) IndicatorRelease(hEMA50);
   if(hADX != INVALID_HANDLE)   IndicatorRelease(hADX);
   if(hStoch != INVALID_HANDLE) IndicatorRelease(hStoch);
}


//==============================================================
// GET VALUE GENERIC
//==============================================================
double GetBufferValue(int handle, int buffer, int shift=0)
{
   if(handle == INVALID_HANDLE)
      return 0.0;

   double val[];
   if(CopyBuffer(handle, buffer, shift, 1, val) <= 0)
      return 0.0;

   return val[0];
}


//==============================================================
// ATR
//==============================================================
double GetATR14(int shift=0)
{
   return GetBufferValue(hATR, 0, shift);
}


//==============================================================
// RSI
//==============================================================
double GetRSI14(int shift=0)
{
   return GetBufferValue(hRSI, 0, shift);
}


//==============================================================
// EMA21
//==============================================================
double GetEMA21(int shift=0)
{
   return GetBufferValue(hEMA21, 0, shift);
}


//==============================================================
// EMA50
//==============================================================
double GetEMA50(int shift=0)
{
   return GetBufferValue(hEMA50, 0, shift);
}


//==============================================================
// ADX
//==============================================================
double GetADX(int shift=0)
{
   return GetBufferValue(hADX, 0, shift);
}


//==============================================================
// STOCHASTIC MAIN
//==============================================================
double GetStochMain(int shift=0)
{
   if(!InpUseStochFilter)
      return 50.0;

   return GetBufferValue(hStoch, 0, shift);
}


//==============================================================
// TREND DIRECTION (EMA21 vs EMA50)
//==============================================================
int GetTrendDirection(int shift=0)
{
   double ema21 = GetEMA21(shift);
   double ema50 = GetEMA50(shift);

   if(ema21 > ema50) return 1;
   if(ema21 < ema50) return -1;
   return 0;
}


//==============================================================
// VOLATILITY REGIME
//==============================================================
int GetVolatilityRegime()
{
   double atr = GetATR14(0);

   if(atr > InpATRPeriod) // logic đơn giản (có thể nâng cấp ML)
      return 1; // high vol
   else if(atr < (InpATRPeriod * 0.5))
      return -1; // low vol
   else
      return 0; // normal
}

#endif