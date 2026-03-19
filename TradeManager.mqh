#ifndef __TRADE_MANAGER_MQH__
#define __TRADE_MANAGER_MQH__

//==============================================================
// TradeManager.mqh
// Quản lý lệnh mở (Institutional Level)
// - Count positions
// - Opposite detection
// - Pyramiding
// - State tracking (trailing / partial / cleanup)
//==============================================================

#include <Trade/Trade.mqh>
#include "ConfigurationInputs.mqh"
#include "LoggingAndTimeUtils.mqh"

//==============================================================

//==============================================================
// COUNT POSITIONS (EA ONLY)
//==============================================================
int CountOpenPositionsThisEA()
{
   int count = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         count++;
   }

   return count;
}

//==============================================================
// COUNT BY TYPE
//==============================================================
int CountOpenPositionsByTypeThisEA(bool isBuy)
{
   int count = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);

      if(isBuy && type == POSITION_TYPE_BUY)
         count++;

      if(!isBuy && type == POSITION_TYPE_SELL)
         count++;
   }

   return count;
}

//==============================================================
// HAS OPPOSITE POSITION
//==============================================================
bool HasOppositePositionThisEA(bool isBuy)
{
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);

      if(isBuy && type == POSITION_TYPE_SELL)
         return true;

      if(!isBuy && type == POSITION_TYPE_BUY)
         return true;
   }

   return false;
}

//==============================================================
// LATEST POSITION TIME
//==============================================================
datetime GetLatestPositionOpenTimeThisEA()
{
   datetime latest = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      datetime t = (datetime)PositionGetInteger(POSITION_TIME);

      if(t > latest)
         latest = t;
   }

   return latest;
}

//==============================================================
// BEST PROFIT DELTA SAME DIR
//==============================================================
double GetBestProfitPriceDeltaSameDir(bool isBuy)
{
   double best = 0.0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);

      if(isBuy && type != POSITION_TYPE_BUY) continue;
      if(!isBuy && type != POSITION_TYPE_SELL) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);

      best = MathMax(best, profit);
   }

   return best;
}

//==============================================================
// CHECK ANY TRAILED
//==============================================================
bool AnySameDirHasSLOrTrailed(bool isBuy)
{
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);

      if(isBuy && type != POSITION_TYPE_BUY) continue;
      if(!isBuy && type != POSITION_TYPE_SELL) continue;

      double sl = PositionGetDouble(POSITION_SL);

      if(sl > 0)
         return true;
   }

   return false;
}

//==============================================================
// PYRAMID SAFE CHECK
//==============================================================
bool CanPyramidSafe(bool isBuy)
{
   if(!InpEnablePyramidingSafe)
      return false;

   int count = CountOpenPositionsByTypeThisEA(isBuy);

   if(count >= InpPyramidMaxAddsPerTrend)
      return false;

   return true;
}

//==============================================================
// SMART PYRAMIDING
//==============================================================
bool AllowSmartPyramiding(bool isBuy)
{
   if(!CanPyramidSafe(isBuy))
      return false;

   double bestProfit = GetBestProfitPriceDeltaSameDir(isBuy);

   if(bestProfit <= 0)
      return false;

   return true;
}

//==============================================================
// CLEANUP PARTIAL (placeholder)
//==============================================================
void CleanupPartialTrack()
{
   // Có thể lưu trạng thái partial bằng GlobalVariable nếu cần
}

//==============================================================
// STATE TRACKERS (placeholder - institutional ready)
//==============================================================
void TrailMarkSet(ulong ticket) {}
void TrailMarkRemove(ulong ticket) {}

void PartialMarkSet(ulong ticket) {}
void PartialMarkRemove(ulong ticket) {}

void CloseReqSet(ulong ticket) {}
void CloseReqRemove(ulong ticket) {}

#endif