#ifndef __INSTITUTIONAL_SMC_MQH__
#define __INSTITUTIONAL_SMC_MQH__

//==============================================================
// InstitutionalSMC.mqh
// Smart Money Concepts (SMC) - Institutional Logic
// Bao gồm:
//  - Liquidity Sweep
//  - Order Block
//  - Fair Value Gap (FVG)
//  - Liquidity Cluster
//  - Orderflow Imbalance
//  - Entry Scoring & Boost
//==============================================================

#include "ConfigurationInputs.mqh"
#include "IndicatorCache.mqh"
#include "TrendAndMTFAnalysis.mqh"

//==============================================================
// LIQUIDITY SWEEP (Multi Swing)
//==============================================================
bool DetectLiquiditySweepMultiSwing(bool isBuy, int lookback=10)
{
   double highMax = -DBL_MAX;
   double lowMin  = DBL_MAX;

   for(int i=1;i<=lookback;i++)
   {
      highMax = MathMax(highMax, iHigh(_Symbol, InpTimeframe, i));
      lowMin  = MathMin(lowMin,  iLow(_Symbol, InpTimeframe, i));
   }

   double lastHigh = iHigh(_Symbol, InpTimeframe, 0);
   double lastLow  = iLow(_Symbol, InpTimeframe, 0);

   if(isBuy)
      return (lastLow < lowMin);   // quét thanh khoản sell
   else
      return (lastHigh > highMax); // quét thanh khoản buy
}

//==============================================================
// ORDER BLOCK (Đơn giản)
//==============================================================
bool DetectOrderBlockBull()
{
   double open1  = iOpen(_Symbol, InpTimeframe, 1);
   double close1 = iClose(_Symbol, InpTimeframe, 1);

   double open2  = iOpen(_Symbol, InpTimeframe, 2);
   double close2 = iClose(_Symbol, InpTimeframe, 2);

   // bearish candle → bullish break
   return (close2 < open2 && close1 > open1 && close1 > open2);
}

bool DetectOrderBlockBear()
{
   double open1  = iOpen(_Symbol, InpTimeframe, 1);
   double close1 = iClose(_Symbol, InpTimeframe, 1);

   double open2  = iOpen(_Symbol, InpTimeframe, 2);
   double close2 = iClose(_Symbol, InpTimeframe, 2);

   return (close2 > open2 && close1 < open1 && close1 < open2);
}

//==============================================================
// FAIR VALUE GAP (FVG)
//==============================================================
bool DetectBullishFVG()
{
   double high2 = iHigh(_Symbol, InpTimeframe, 2);
   double low0  = iLow(_Symbol, InpTimeframe, 0);

   return (low0 > high2);
}

bool DetectBearishFVG()
{
   double low2  = iLow(_Symbol, InpTimeframe, 2);
   double high0 = iHigh(_Symbol, InpTimeframe, 0);

   return (high0 < low2);
}

//==============================================================
// LIQUIDITY DISTANCE
//==============================================================
double GetLiquidityDistance()
{
   double high = iHigh(_Symbol, InpTimeframe, 10);
   double low  = iLow(_Symbol, InpTimeframe, 10);

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   return MathMin(MathAbs(price - high), MathAbs(price - low));
}

//==============================================================
// VOLATILITY REGIME AI (simple version)
//==============================================================
int GetVolatilityRegimeAI()
{
   double atr = GetATR14();

   if(atr > 6.0) return 1;     // high
   if(atr < 3.0) return -1;    // low
   return 0;                   // normal
}

//==============================================================
// LIQUIDITY CLUSTER
//==============================================================
bool DetectLiquidityCluster()
{
   double high1 = iHigh(_Symbol, InpTimeframe, 1);
   double high2 = iHigh(_Symbol, InpTimeframe, 2);
   double high3 = iHigh(_Symbol, InpTimeframe, 3);

   double range = MathAbs(high1 - high3);

   return (range < GetATR14() * 0.5);
}

//==============================================================
// ORDERFLOW IMBALANCE
//==============================================================
bool DetectOrderflowImbalance(bool isBuy)
{
   double vol1 = iVolume(_Symbol, InpTimeframe, 1);
   double vol2 = iVolume(_Symbol, InpTimeframe, 2);

   if(isBuy)
      return (vol1 > vol2 * 1.2);
   else
      return (vol1 < vol2 * 0.8);
}

//==============================================================
// ADAPTIVE ENTRY SCORE
//==============================================================
double CalculateAdaptiveEntryScore(bool isBuy)
{
   double score = 0.0;

   if(DetectLiquiditySweepMultiSwing(isBuy)) score += 1.0;
   if(isBuy && DetectOrderBlockBull()) score += 1.0;
   if(!isBuy && DetectOrderBlockBear()) score += 1.0;

   if(isBuy && DetectBullishFVG()) score += 0.8;
   if(!isBuy && DetectBearishFVG()) score += 0.8;

   if(DetectLiquidityCluster()) score += 0.5;
   if(DetectOrderflowImbalance(isBuy)) score += 0.7;

   return score;
}

//==============================================================
// ADAPTIVE ENTRY BOOST
//==============================================================
double AdaptiveEntryBoost(bool isBuy)
{
   double score = CalculateAdaptiveEntryScore(isBuy);

   if(score >= 3.0) return 1.5;
   if(score >= 2.0) return 1.2;
   return 1.0;
}

//==============================================================
// INSTITUTIONAL SCORE
//==============================================================
double GetInstitutionalScore(bool isBuy)
{
   double score = 0;

   if(DetectLiquiditySweepMultiSwing(isBuy)) score += 1;
   if(DetectLiquidityCluster()) score += 1;
   if(DetectOrderflowImbalance(isBuy)) score += 1;

   return score;
}

#endif