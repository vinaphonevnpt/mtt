#ifndef __RISK_MANAGEMENT_AND_EXIT_MQH__
#define __RISK_MANAGEMENT_AND_EXIT_MQH__

#include <Trade/Trade.mqh>
#include "ConfigurationInputs.mqh"
#include "LoggingAndTimeUtils.mqh"

//==============================================================
double GetADXValue_RM()
{
   int handle=iADX(_Symbol,_Period,InpADXPeriod);
   if(handle==INVALID_HANDLE) return 0;

   double buf[];
   if(CopyBuffer(handle,0,0,1,buf)<=0) return 0;

   return buf[0];
}

//==============================================================
void CloseAllPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol=PositionGetString(POSITION_SYMBOL);
      double volume=PositionGetDouble(POSITION_VOLUME);
      int type=(int)PositionGetInteger(POSITION_TYPE);

      MqlTradeRequest req;
      MqlTradeResult res;

      ZeroMemory(req);
      ZeroMemory(res);

      req.action=TRADE_ACTION_DEAL;
      req.symbol=symbol;
      req.volume=volume;
      req.type=(type==POSITION_TYPE_BUY)?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
      req.price=SymbolInfoDouble(symbol,SYMBOL_BID);
      req.deviation=20;

      if(!OrderSend(req,res))
      {
         Print("Close fail: ",res.retcode);
      }
   }
}

//==============================================================
void ApplyADXExit()
{
   double adx = GetADXValue_RM();

   if(adx < 20)
   {
      Log("📉 ADX yếu → đóng | cần>20 | hiện=" + DoubleToString(adx,1));
      CloseAllPositions();
   }
}

//==============================================================
void ManageOpenPositions()
{
   ApplyADXExit();
}

#endif