#ifndef __EXECUTION_ENGINE_MQH__
#define __EXECUTION_ENGINE_MQH__

#include <Trade/Trade.mqh>
#include "ConfigurationInputs.mqh"
#include "AdaptiveFrequencyEngine.mqh"
#include "SignalCore.mqh"
#include "MLAndONNX.mqh"

CTrade trade;

//==============================================================
void AttemptEntry()
{
   static datetime lastEntry=0;

   if((TimeCurrent()-lastEntry)<InpMinSecondsBetweenEntries)
      return;

   string reason="";

   if(!ScalpingProGate(true,reason))
   {
      Log("❌ NO TRADE BUY | " + reason);
      return;
   }

   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   price=ApplyMLExcursionTP(price,true);

   MqlTradeRequest req;
   MqlTradeResult  res;

   ZeroMemory(req);
   ZeroMemory(res);

   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = _Symbol;
   req.volume   = InpFixedLot;
   req.type     = ORDER_TYPE_BUY;
   req.price    = price;
   req.deviation= InpSlippagePoints;

   if(OrderSend(req,res))
      Log("✅ BUY OK | price=" + DoubleToString(price,_Digits));
   else
      Log("❌ BUY FAIL | ret=" + IntegerToString(res.retcode));

   lastEntry=TimeCurrent();
}

#endif