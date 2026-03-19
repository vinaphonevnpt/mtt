#ifndef __SESSION_AND_TIME_FILTER_MQH__
#define __SESSION_AND_TIME_FILTER_MQH__

//==============================================================
// SessionAndTimeFilter.mqh (HEDGE FUND VERSION)
// - Không spam log
// - Log theo STATE CHANGE
// - Adaptive session parameters
//==============================================================

#include "ConfigurationInputs.mqh"
#include "LoggingAndTimeUtils.mqh"


//==============================================================
// SESSION DETECTION
//==============================================================
bool IsLondonNYSessionNow()
{
   int h = GetHourNow();
   return (h >= 13 && h <= 22); // EU + US overlap
}

bool IsAsiaLikeSessionNow()
{
   int h = GetHourNow();
   return (h >= 0 && h <= 8);
}

//==============================================================
// STATE LOG (ANTI-SPAM)
//==============================================================
void LogSessionState(string state)
{
   static string lastState = "";

   if(state != lastState)
   {
      Log("[SESSION] " + state);
      lastState = state;
   }
}

//==============================================================
// SESSION FACTOR
//==============================================================
double SessionThresholdFactor()
{
   if(IsLondonNYSessionNow())
   {
      LogSessionState("Session mạnh → siết điều kiện");
      return InpLondonNYSessionTightFactor;
   }

   if(IsAsiaLikeSessionNow())
   {
      LogSessionState("Session yếu → nới điều kiện");
      return InpAsiaSessionLoosenFactor;
   }

   LogSessionState("Session trung tính");
   return 1.0;
}

//==============================================================
// TIME FILTER CORE
//==============================================================
bool CanTradeNow_Time(string &reason)
{
   if(!InpUseTimeFilter)
      return true;

   int h = GetHourNow();

   if(h < InpTradeStartHour || h > InpTradeEndHour)
   {
      reason = "Ngoài giờ giao dịch";
      return false;
   }

   // Block trước phiên
   if(InpBlockBeforeSessions)
   {
      int nowMin = GetHourNow()*60 + GetMinuteNow();

      int euMin = 14*60; // EU start fixed
      int usMin = 19*60; // US start fixed

      if(MathAbs(nowMin - euMin) <= InpBlockBeforeEU_Min)
      {
         reason = "Trước phiên EU";
         return false;
      }

      if(MathAbs(nowMin - usMin) <= InpBlockBeforeUS_Min)
      {
         reason = "Trước phiên US";
         return false;
      }
   }

   return true;
}

//==============================================================
// APPLY ADAPTIVE PARAMETERS (HOOK)
//==============================================================
void ApplySessionAdaptiveParameters()
{
   double factor = SessionThresholdFactor();

   // Có thể scale các ngưỡng tại đây nếu cần
   // (RSI, Spread, ML threshold...)

   // Hiện tại chỉ dùng factor cho các module khác đọc
}

//==============================================================
#endif