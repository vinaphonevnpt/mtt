//+------------------------------------------------------------------+
//|      AutoConditionsEA_Modular_MAIN.mq5 (FINAL INSTITUTIONAL)     |
//+------------------------------------------------------------------+
#property strict

//==============================================================
// INCLUDE 14 MODULES (ĐÚNG THỨ TỰ)
//==============================================================
#include "ConfigurationInputs.mqh"
#include "AdaptiveFrequencyEngine.mqh"
#include "LoggingAndTimeUtils.mqh"
#include "IndicatorCache.mqh"
#include "TrendAndMTFAnalysis.mqh"
#include "SignalCore.mqh"
#include "InstitutionalSMC.mqh"
#include "NewsAndSentiment.mqh"
#include "MLAndONNX.mqh"
#include "ExecutionEngine.mqh"
#include "TradeManager.mqh"
#include "RiskManagementAndExit.mqh"
#include "SessionAndTimeFilter.mqh"

//==============================================================
// GLOBAL STATE
//==============================================================
datetime gLastBarTime = 0;

//==============================================================
// CHECK NEW BAR
//==============================================================
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);

   if(currentBarTime != gLastBarTime)
   {
      gLastBarTime = currentBarTime;
      return true;
   }

   return false;
}

//==============================================================
// INIT
//==============================================================
int OnInit()
{
   Log("=== EA INITIALIZED ===");

   InitIndicatorCache();
   UpdateFrequencyBoostSettings();

   return(INIT_SUCCEEDED);
}

//==============================================================
// DEINIT
//==============================================================
void OnDeinit(const int reason)
{
   Log("=== EA STOPPED ===");
}

//==============================================================
// MAIN LOOP
//==============================================================
void OnTick()
{
   string reason="";

   //==========================================================
   // FREQUENCY ENGINE
   //==========================================================
   UpdateFrequencyBoostSettings();

   //==========================================================
   // SESSION ADAPTIVE
   //==========================================================
   ApplySessionAdaptiveParameters();

   //==========================================================
   // TRADE ON NEW BAR
   //==========================================================
   if(InpTradeOnNewBar)
   {
      if(!IsNewBar())
         return;
   }

   //==========================================================
   // TIME FILTER (core nằm trong LoggingAndTimeUtils)
   //==========================================================
   if(!CanTradeNow_Time(reason))
   {
      LogBlockedOnce(reason);
      return;
   }

   //==========================================================
   // ENTRY ENGINE
   //==========================================================
   AttemptEntry();

   //==========================================================
   // POSITION MANAGEMENT
   //==========================================================
   ManageOpenPositions();
}

//==============================================================
// TRADE TRANSACTION (OPTIONAL DEBUG)
//==============================================================
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(InpVerboseLogs)
   {
      Log("Trade transaction update");
   }
}