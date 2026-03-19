#ifndef __ADAPTIVE_FREQUENCY_ENGINE_MQH__
#define __ADAPTIVE_FREQUENCY_ENGINE_MQH__

//==============================================================
// AdaptiveFrequencyEngine.mqh (HEDGE FUND + EXTENDED GATE)
// - Dynamic Frequency Mode
// - Adaptive filters (Spread / ML / Volume / Anti-chase)
// - Gate quyết định cho phép trade hay không
// - Anti-spam logging (state-based)
//==============================================================

#include "ConfigurationInputs.mqh"
#include "LoggingAndTimeUtils.mqh"
#include "IndicatorCache.mqh"

//==============================================================
// GLOBAL STATE
//==============================================================
int    gFreqMode        = FREQ_MODE_OFF;
double gSpreadMult      = 1.0;
double gMLAdjust        = 0.0;
double gVolumeMult      = 1.0;
bool   gAllowAntiChase  = true;

//==============================================================
// LOG STATE (ANTI-SPAM)
//==============================================================
void LogFrequencyState(int mode, double spreadMult, double mlAdj)
{
   static int lastMode = -999;
   static double lastSpread = -999;
   static double lastML = -999;

   if(mode != lastMode ||
      MathAbs(spreadMult - lastSpread) > 0.0001 ||
      MathAbs(mlAdj - lastML) > 0.0001)
   {
      Log("[FREQ] Mode=" + IntegerToString(mode) +
          " SpreadMult=" + DoubleToString(spreadMult,2) +
          " MLAdj=" + DoubleToString(mlAdj,2));

      lastMode   = mode;
      lastSpread = spreadMult;
      lastML     = mlAdj;
   }
}


//==============================================================
// HÀM MỚI: ÁP DỤNG BẢNG 3 CẤP ĐỘ
//==============================================================
void ApplyFrequencySettings()
{
   switch(InpFrequencyMode)
   {
      case FREQ_OFF:
         gSpreadMult      = 1.80;
         gMLAdjust        = 0.0;
         gVolumeMult      = 1.08;
         gAllowAntiChase  = true;
         break;

      case FREQ_MED:
         gSpreadMult      = 1.50;
         gMLAdjust        = -0.05;
         gVolumeMult      = 1.04;
         gAllowAntiChase  = true;
         break;

      case FREQ_HIGH:
         gSpreadMult      = 1.30;
         gMLAdjust        = -0.10;
         gVolumeMult      = 0.0;   // bỏ filter volume
         gAllowAntiChase  = false;
         break;
   }
}

//==============================================================
// HÀM CŨ ĐÃ NÂNG CẤP (UpdateFrequencyBoostSettings)
//==============================================================
void UpdateFrequencyBoostSettings()
{
   ApplyFrequencySettings();   // Gọi hàm mới để áp dụng bảng 3 cấp độ
   LogFrequencyState(InpFrequencyMode, gSpreadMult, gMLAdjust);
}
//==============================================================
// ADAPTIVE HELPERS
//==============================================================
double GetAdaptiveSpreadMultiplier()
{
   return gSpreadMult;
}

double GetAdaptiveMLThresholdAdjust()
{
   return gMLAdjust;
}

double GetAdaptiveVolumeMultiplier()
{
   return gVolumeMult;
}

bool GetAdaptiveAntiChase()
{
   return gAllowAntiChase;
}

bool UseStrictMTF()
{
   return (gFreqMode == FREQ_MODE_OFF);
}

bool UseSRFilter()
{
   return (gFreqMode != FREQ_MODE_HIGH);
}

bool AllowNewsTrade()
{
   return (gFreqMode == FREQ_MODE_HIGH);
}

//==============================================================
// CORE GATE (HEDGE FUND LOGIC)
//==============================================================
bool FrequencyAdaptiveGate(string &reason)
{
   //==========================================================
   // 1. VOLATILITY CHECK (ATR BASED)
   //==========================================================
   double atr = GetATR14();

   if(atr <= 0)
   {
      reason = "ATR không hợp lệ";
      return false;
   }

   // Low volatility → hạn chế trade
   if(atr < 2.0 && gFreqMode == FREQ_MODE_OFF)
   {
      reason = "Volatility thấp";
      return false;
   }

   //==========================================================
   // 2. SPREAD CHECK (ADAPTIVE)
   //==========================================================
   if(InpUseMaxSpread)
   {
      int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double maxSpread = InpMaxSpreadPoints * gSpreadMult;

      if(spread > maxSpread)
      {
         reason = "Spread vượt ngưỡng adaptive";
         return false;
      }
   }

   //==========================================================
   // 3. SESSION + MODE LOGIC
   //==========================================================
   // OFF mode → rất chặt
   if(gFreqMode == FREQ_MODE_OFF)
   {
      // yêu cầu volatility đủ lớn
      if(atr < 3.0)
      {
         reason = "ATR chưa đủ cho mode OFF";
         return false;
      }
   }

   // MED mode → cân bằng
   if(gFreqMode == FREQ_MODE_MED)
   {
      if(atr < 2.0)
      {
         reason = "ATR thấp (MED)";
         return false;
      }
   }

   // HIGH mode → gần như luôn cho phép
   if(gFreqMode == FREQ_MODE_HIGH)
   {
      // vẫn chặn nếu cực thấp
      if(atr < 1.0)
      {
         reason = "Thị trường chết (ATR cực thấp)";
         return false;
      }
   }

   //==========================================================
   // 4. TICK VOLUME FILTER (OPTIONAL INSTITUTIONAL)
   //==========================================================
   if(InpUseTickVolumeBreakoutFilter)
   {
      long vol0 = (long)iVolume(_Symbol, _Period, 0);
      long vol1 = (long)iVolume(_Symbol, _Period, 1);

      if(vol0 < vol1 * 0.7 && gFreqMode != FREQ_MODE_HIGH)
      {
         reason = "Volume yếu";
         return false;
      }
   }

   //==========================================================
   // 5. FINAL PASS
   //==========================================================
   return true;
}

//==============================================================
#endif