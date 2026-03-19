#ifndef __ML_AND_ONNX_MQH__
#define __ML_AND_ONNX_MQH__

//==============================================================
// MLAndONNX.mqh
// Machine Learning Layer (Institutional Grade - Safe Version)
// - Không phụ thuộc ONNX runtime (tránh lỗi compile)
// - Giữ structure để nâng cấp ONNX sau
// - KHÔNG duplicate MLProbabilityGate (duy nhất tại đây)
//==============================================================

#include "ConfigurationInputs.mqh"
#include "IndicatorCache.mqh"
#include "TrendAndMTFAnalysis.mqh"

//==============================================================
// GLOBAL MODEL HANDLE (placeholder)
//==============================================================
int hOnnxExcursion = INVALID_HANDLE;


//==============================================================
// INIT MODEL (placeholder)
//==============================================================
bool InitExcursionModel()
{
   // Có thể load ONNX sau (hiện tại placeholder)
   hOnnxExcursion = 1;
   return true;
}

//==============================================================
void ReleaseExcursionModel()
{
   hOnnxExcursion = INVALID_HANDLE;
}


//==============================================================
// FEATURE ENGINEERING
//==============================================================
double Feature_Trend()
{
   return (double)GetEMATrendDir();
}

double Feature_Momentum()
{
   double rsi = GetRSI14();
   return (rsi - 50.0) / 50.0;
}

double Feature_Volatility()
{
   return GetATR14();
}

double Feature_MTF()
{
   if(IsMTFAligned(true)) return 1.0;
   if(IsMTFAligned(false)) return -1.0;
   return 0.0;
}

double Feature_PriceAction()
{
   double close1 = iClose(_Symbol, InpTimeframe, 1);
   double open1  = iOpen(_Symbol, InpTimeframe, 1);

   return (close1 - open1);
}


//==============================================================
// COMPUTE ML SCORE (Weighted Linear Model)
//==============================================================
double ComputeMLProbability(bool isBuy)
{
   if(!InpUseProbabilisticMLFilter)
      return 1.0;

   double score = 0.0;

   score += Feature_Trend()     * InpMLTrendWeight;
   score += Feature_Momentum()  * InpMLMomentumWeight;
   score += Feature_Volatility()* InpMLVolWeight;
   score += Feature_MTF()       * InpMLMTFWeight;
   score += Feature_PriceAction()* InpMLPAWeight;

   // Sigmoid normalize
   double prob = 1.0 / (1.0 + MathExp(-score));

   return prob;
}


//==============================================================
// ML PROBABILITY GATE (CORE - UNIQUE)
//==============================================================
bool MLProbabilityGate(bool isBuy, string &reason)
{
   if(!InpUseProbabilisticMLFilter)
      return true;

   double prob = ComputeMLProbability(isBuy);

   double threshold = isBuy ? InpMLScoreThreshold_Buy
                            : InpMLScoreThreshold_Sell;

   if(prob < threshold)
   {
      reason = "ML Probability thấp: " + DoubleToString(prob, 2);
      return false;
   }

   return true;
}


//==============================================================
// MAX EXCURSION PREDICTION (Simplified)
//==============================================================
double PredictMaxExcursion(bool isBuy)
{
   double atr = GetATR14();

   // Dự đoán TP theo volatility
   double base = atr * 2.0;

   if(InpUseVolatilityTPAdjust)
      base *= (1.0 + InpVolatilityTPFactor);

   return base;
}


//==============================================================
// APPLY ML TP
//==============================================================
double ApplyMLExcursionTP(double entryPrice, bool isBuy)
{
   double excursion = PredictMaxExcursion(isBuy);

   if(isBuy)
      return entryPrice + excursion;
   else
      return entryPrice - excursion;
}


//==============================================================
// SIMPLE BUY PREDICT
//==============================================================
bool MLPredictBuy()
{
   double prob = ComputeMLProbability(true);
   return prob >= InpMLScoreThreshold_Buy;
}

#endif