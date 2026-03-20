


double GetAdaptiveSpreadMultiplier()
{
   if(InpFrequencyMode == FREQ_MED) return 1.50;
   if(InpFrequencyMode == FREQ_HIGH) return 1.30;
   return 1.80;
}


double GetAdaptiveVolumeMultiplier()
{
   if(InpFrequencyMode == FREQ_MED) return 1.04;
   if(InpFrequencyMode == FREQ_HIGH) return 0.0;
   return 1.08;
}


bool UsePriceActionConfirm()
{
   if(InpFrequencyMode == FREQ_OFF) return true;
   if(InpFrequencyMode == FREQ_MED) return false;
   if(InpFrequencyMode == FREQ_HIGH) return false;
   return true;
}


bool UseTrendIndicators()
{
   if(InpFrequencyMode == FREQ_HIGH)
      return false;
   return true;
}


double gFreqRSIRelax      = 1.0;
double gFreqATRRelax      = 1.0;
double gFreqVolumeRelax   = 1.0;
double gFreqMLRelax       = 1.0;
int    gFreqMinEntryDelay = 30;

// ===== Added globals for merged modules =====
long hOnnxExcursion = INVALID_HANDLE;
input int InpMaxPyramidLevels = 3;

//+------------------------------------------------------------------+
//| AutoConditionsEA_XAU_v4.236_PRO_MTF_ULTRA.mq5            |
//| v4.236 ULTRA (FULL CODE)                                          |
//|  - FIX: Pullback vs EnvTight RSI conflict (no impossible gating)  |
//|  - FIX: Dynamic spread cap floor + ATR% (avoid self-lock at ATR low)|
//|  - FIX: SRConfirm can be SOFT (no full OUT), with risk-tightening |
//|  - FIX: FixStops precedence vs RRStops (clear override rule)      |
//|  - IMPLEMENT: PriceActionConfirm minimal (Doji/Pinbar)            |
//|  - ADD: Adaptive thresholds for both volatile and calm markets    |
//|  - TUNE: reduce over-filter on XAUUSD M5 while preserving safety  |
//|  - KEEP: v4.231 structure & core logic                            |
//+------------------------------------------------------------------+
#property strict

// ==== ATR HANDLES (FIXED GLOBAL) ====
int hATR_regime = INVALID_HANDLE;
int hATR_regime14 = INVALID_HANDLE;
int hATR_regimeFast = INVALID_HANDLE;
int hATR_regimeSlow = INVALID_HANDLE;
int hATR_AI = INVALID_HANDLE;

int hATR = INVALID_HANDLE;
// ===== v5.500 Institutional AI Ultra =====
//================ CÀI ĐẶT SMART SESSION =================
input bool InpEnableSmartSessionScalper = true;
input bool InpEnableAIVolatilityRegime = true;
//================ SMART MONEY / LIQUIDITY =================
input bool InpEnableLiquidityMap = true;


input bool InpVerboseNoTradeLog = true;      // enable frequent no-trade logs
input int  InpNoTradeLogIntervalSec = 10;    // seconds between no-trade logs

input bool InpAggressiveMode = false; // high frequency mode
input bool   InpUseXSentiment = false;
input double InpBearishThreshold = 0.55;

input bool InpDebugLogs = true; // Diagnostic logging

#property version "4.236"

#include <Trade/Trade.mqh>
CTrade trade;

//================ TIMEZONE DISPLAY MODULE =================//
enum ENUM_DISPLAY_TIMEZONE
{
   TZ_SERVER = 0,
   TZ_VIETNAM,
   TZ_LONDON,
   TZ_NEWYORK,
   TZ_TOKYO,
   TZ_SYDNEY
};

input ENUM_DISPLAY_TIMEZONE InpDisplayTimeZone = TZ_VIETNAM;

int GetTimezoneOffsetHours(ENUM_DISPLAY_TIMEZONE tz)
{
   switch(tz)
   {
      case TZ_SERVER:  return 0;
      case TZ_VIETNAM: return 7;
      case TZ_LONDON:  return 0;
      case TZ_NEWYORK: return -5;
      case TZ_TOKYO:   return 9;
      case TZ_SYDNEY:  return 10;
   }
   return 0;
}

datetime gLastNoTradeLogTime=0;
datetime ConvertServerTime(datetime serverTime)
{
   int offset = GetTimezoneOffsetHours(InpDisplayTimeZone);
   datetime gmt = serverTime - TimeGMTOffset();
   datetime target = gmt + offset * 3600;
   return target;
}

string GetDisplayTimeString()
{
   datetime t = ConvertServerTime(TimeCurrent());
   return TimeToString(t, TIME_DATE | TIME_MINUTES);
}

string GetTimezoneName()
{
   switch(InpDisplayTimeZone)
   {
      case TZ_SERVER:  return "SERVER";
      case TZ_VIETNAM: return "VN";
      case TZ_LONDON:  return "LONDON";
      case TZ_NEWYORK: return "NEWYORK";
      case TZ_TOKYO:   return "TOKYO";
      case TZ_SYDNEY:  return "SYDNEY";
   }
   return "SERVER";
}
//===========================================================
//==================== MTF TREND INPUT FIX ====================//
input ENUM_TIMEFRAMES InpTrendTF1 = PERIOD_M15;
input ENUM_TIMEFRAMES InpTrendTF2 = PERIOD_H1;

//==================== EMA TREND FUNCTION FIX ====================//
int GetEMATrendDir(ENUM_TIMEFRAMES tf)
{
   int fast=21;
   int slow=50;

   double emaFast[3];
   double emaSlow[3];

   int hFast=iMA(_Symbol,tf,fast,0,MODE_EMA,PRICE_CLOSE);
   int hSlow=iMA(_Symbol,tf,slow,0,MODE_EMA,PRICE_CLOSE);

   if(hFast==INVALID_HANDLE || hSlow==INVALID_HANDLE)
   if(hFast==INVALID_HANDLE || hSlow==INVALID_HANDLE)
      return 0;


      return 0;

   if(CopyBuffer(hFast,0,0,3,emaFast)<=0) return 0;
   if(CopyBuffer(hSlow,0,0,3,emaSlow)<=0) return 0;

   IndicatorRelease(hFast);
   IndicatorRelease(hSlow);

   if(emaFast[0]>emaSlow[0]) return 1;
   if(emaFast[0]<emaSlow[0]) return -1;


   return 0;
}
//================ INDICATOR HANDLE CACHE (v4.600) ================
int hATR14 = INVALID_HANDLE;
int hRSI14 = INVALID_HANDLE;
int hEMA21 = INVALID_HANDLE;
int hEMA50 = INVALID_HANDLE;

bool InitIndicatorCache()
{
   hATR14 = iATR(_Symbol,_Period,14);
   hRSI14 = iRSI(_Symbol,_Period,14,PRICE_CLOSE);
   hEMA21 = iMA(_Symbol,_Period,21,0,MODE_EMA,PRICE_CLOSE);
   hEMA50 = iMA(_Symbol,_Period,50,0,MODE_EMA,PRICE_CLOSE);

   if(hATR14==INVALID_HANDLE || hRSI14==INVALID_HANDLE || hEMA21==INVALID_HANDLE || hEMA50==INVALID_HANDLE)
      return false;

   return true;
}

double GetATR14(int shift=0)
{
   double buf[];
   if(CopyBuffer(hATR_regime14,0,shift,1,buf)<=0) return 0;
   return buf[0];
}

double GetRSI14(int shift=0)
{
   double buf[];
   if(CopyBuffer(hRSI14,0,shift,1,buf)<=0) return 50;
   return buf[0];
}

double GetEMA21(int shift=0)
{
   double buf[];
   if(CopyBuffer(hEMA21,0,shift,1,buf)<=0) return 0;
   return buf[0];
}

double GetEMA50(int shift=0)
{
   double buf[];
   if(CopyBuffer(hEMA50,0,shift,1,buf)<=0) return 0;
   return buf[0];
}
//===============================================================


//==================== Inputs ====================//

//--------------------------------------------------
// 01) Cài đặt chung & quản lý vốn
//--------------------------------------------------
input group "01) Cài đặt chung & quản lý vốn";
input ENUM_TIMEFRAMES InpTimeframe            = PERIOD_M5;      // Khung thời gian tính tín hiệu chính
input long            InpMagicNumber          = 20260224;       // Magic Number để nhận diện lệnh của EA
input double          InpFixedLot             = 0.01;           // Khối lượng vào lệnh cố định
input double          InpMaxRiskPercent       = 2.0;            // Rủi ro tiền tối đa cho 1 lệnh (% Balance), chỉ dùng để CHẶN lệnh nếu fixed lot quá rủi ro
input bool            InpBlockTradeIfRiskTooHigh = true;        // Chặn lệnh nếu lot cố định + SL hiện tại vượt rủi ro cho phép
input bool            InpOnePositionPerSymbol = false;          // Mỗi symbol chỉ giữ tối đa 1 lệnh
input int             InpMaxOpenPositions     = 2;              // Số lệnh tối đa EA được phép mở cùng lúc
input bool            InpCloseOppositePositions = false;       // Đóng lệnh ngược chiều trước khi mở lệnh mới

//--------------------------------------------------
// 02) Quản lý StopLoss / TakeProfit / Break-even / Trailing
//--------------------------------------------------
input group "02) Quản lý StopLoss / TakeProfit / Break-even / Trailing";
input int             InpSpreadBufferPips     = 15;             // Khoảng đệm SL theo spread/pips dưới đáy hoặc trên đỉnh nến tín hiệu
input bool            InpEnableBreakEven      = true;           // Bật dời SL về hòa vốn
input double          InpBEThreshold          = 0.50;           // Dời SL về Entry khi giá đi được X phần quãng đường tới TP
input double          InpBE_RR_Trigger        = 1.00;           // Smart BE: chỉ dời về hòa vốn khi lợi nhuận đạt tối thiểu X lần khoảng SL ban đầu
input double          InpBE_OffsetPrice       = 0.35;           // Smart BE: offset cộng thêm sau điểm hòa vốn để tránh bị quét lại ngay
input bool            InpFixStops             = false;          // Dùng SL/TP cố định theo khoảng cách step
input double          InpStopLossStepPrice    = 7.5;            // Khoảng cách StopLoss cố định (đơn vị giá)
input double          InpTakeProfitStepPrice  = 4.5;            // Khoảng cách TakeProfit cố định (đơn vị giá)
input bool            InpAllowRROverrideFixStops = false;       // Cho phép RR Stops ghi đè FixStops
input bool            InpUseTrailingStop      = true;           // Bật trailing stop
input double          InpTrailStartPrice      = 3.2;            // Bắt đầu trailing khi lệnh có lời đạt mức này
input double          InpTrailStepPrice       = 1.2;            // Bước dời SL mỗi lần trailing

//--------------------------------------------------
// 03) Tần suất vào lệnh & ghi log
//--------------------------------------------------
input group "03) Tần suất vào lệnh & ghi log";
input bool            InpTradeOnNewBar        = true;           // Chỉ xét vào lệnh khi có nến mới
input bool            InpUseClosedBarSignals  = true;           // Chỉ dùng tín hiệu từ nến đã đóng
input int             InpMinSecondsBetweenEntries    = 30;      // Khoảng cách tối thiểu (giây) giữa 2 lần vào lệnh
input int             InpMinMinutesBetweenPositions  = 1;       // Khoảng cách tối thiểu (phút) giữa 2 vị thế
input bool            InpVerboseLogs          = false;          // Bật log kỹ thuật / phân tích chi tiết
input bool            InpEnableBlockLogs      = true;           // Bật log chặn lệnh dạng: Không vào lệnh do...
input bool            InpLogNoSignal          = true;           // Ghi log khi không có tín hiệu phù hợp

//--------------------------------------------------
// 04) Bộ lọc spread / slippage / môi trường giao dịch
//--------------------------------------------------
input group "04) Bộ lọc spread / slippage / môi trường giao dịch";
input bool            InpUseMaxSpread         = true;           // Bật giới hạn spread tối đa
input int             InpMaxSpreadPoints      = 250;            // Spread tối đa cho phép (points)
input int             InpSlippagePoints       = 50;             // Slippage tối đa khi khớp lệnh (points)
input double          InpSpreadAtrPct         = 0.10;           // Tỷ lệ spread động theo ATR
input int             InpMinSpreadCapPoints   = 35;             // Mức sàn spread cap tối thiểu
input bool            InpUseDynamicSpreadAbnormalBlock = true;  // Chặn nếu spread hiện tại dị thường so với trung bình gần đây
input int             InpSpreadTelemetrySamples = 24;           // Số mẫu spread dùng để đánh giá bất thường
input double          InpSpreadAbnormalMultiplier = 1.80;       // Spread hiện tại > trung bình * hệ số này thì chặn

//--------------------------------------------------
// 05) Bộ lọc xu hướng & lực giá TREND
//--------------------------------------------------
input group "05) Bộ lọc xu hướng & lực giá TREND";
input bool   InpForceTrendEverywhere   = true;                  // Luôn ưu tiên vào lệnh theo TREND, không dùng entry RANGE/VOL trực tiếp
input double InpTrendTight_RSI_BuyMin  = 52.0;                 // Khi môi trường xấu + TREND_FOLLOW: BUY chỉ cho phép nếu RSI >= ngưỡng này
input double InpTrendTight_RSI_SellMax = 48.0;                 // Khi môi trường xấu + TREND_FOLLOW: SELL chỉ cho phép nếu RSI <= ngưỡng này
input double InpTightPullback_MinADX        = 8.0;            // Khi môi trường xấu + PULLBACK: yêu cầu ADX tối thiểu
input int    InpTightPullback_ExtraGapSec   = 10;              // Khi môi trường xấu + PULLBACK: cộng thêm khoảng cách giây
input int    InpTightPullback_ExtraGapMin   = 0;               // Khi môi trường xấu + PULLBACK: cộng thêm khoảng cách phút
input int    InpTightPullback_MaxOpenCap    = 1;               // Khi môi trường xấu + PULLBACK: giới hạn số lệnh tối đa
input int    InpPullbackRecentCrossBars    = 3;               // Số nến gần nhất cho phép xem là giao cắt EMA còn hiệu lực trên M5
input bool   InpEnablePullbackTrendFollowFallback = true;      // Nếu không có pullback đẹp, cho phép fallback theo TREND_FOLLOW mềm hơn trên M5

//--------------------------------------------------
// 05A) PRO-MTF tự động theo khung thời gian
//--------------------------------------------------
input group "05A) PRO-MTF tự động theo khung thời gian";
input bool   InpAutoTrendModeByTF          = true;               // Tự động chọn TREND_FOLLOW cho M1-M5 và TREND_PULLBACK cho M15+
input bool   InpUseStrictMTF         = true;               // Yêu cầu H1 và M15 cùng hướng khi bật lọc đa khung
input bool   InpDisableRecoveryOnM1ToM5    = true;               // Tắt Recovery Profit Close trên M1-M5 để tránh cắt lời quá sớm
input double InpM1M5_FollowBuyRSIMin       = 48.0;               // M1-M5 TREND_FOLLOW: BUY khi RSI >= ngưỡng này
input double InpM1M5_FollowSellRSIMax      = 52.0;               // M1-M5 TREND_FOLLOW: SELL khi RSI <= ngưỡng này
input double InpM1M5_StochBuyMinK          = 24.0;               // M1-M5 TREND_FOLLOW: K tối thiểu cho BUY
input double InpM1M5_StochBuyCrossMinK     = 15.0;               // M1-M5 TREND_FOLLOW: K tối thiểu khi BUY cắt lên
input double InpM1M5_StochSellMaxK         = 76.0;               // M1-M5 TREND_FOLLOW: K tối đa cho SELL
input double InpM1M5_StochSellCrossMaxK    = 85.0;               // M1-M5 TREND_FOLLOW: K tối đa khi SELL cắt xuống
input double InpM1M5_TrailStartPrice       = 6.0;                // M1-M5: bắt đầu trailing muộn hơn để tránh cắt non
input double InpM1M5_TrailStepPrice        = 2.4;                // M1-M5: bước trailing rộng hơn
input int    InpM15Plus_RecentCrossBars    = 5;                  // M15+: số nến recent cross cho pullback
input double InpM15Plus_PullbackBuyRSIMax  = 46.0;               // M15+: BUY pullback khi RSI <= ngưỡng này
input double InpM15Plus_PullbackSellRSIMin = 54.0;               // M15+: SELL pullback khi RSI >= ngưỡng này
input double InpM15Plus_TrailStartPrice    = 4.5;                // M15+: trailing bắt đầu từ mức này
input double InpM15Plus_TrailStepPrice     = 1.8;                // M15+: bước trailing

//--------------------------------------------------
// 05B) PRO-MTF FIX v4.234: trend / anti-chase / hybrid SL / BE ATR / volume / 3-layer MTF
//--------------------------------------------------
input group "05B) PRO-MTF FIX v4.234";
input bool   InpUseEnhancedTrendDirection  = true;                // Bật bộ lọc hướng xu hướng nâng cấp
input double InpTrendSlopeMinPrice         = 0.07;                // Độ dốc EMA21 tối thiểu giữa 2 nến đã đóng
input double InpTrendSeparationMinPrice    = 0.10;                // Khoảng cách EMA21-EMA50 tối thiểu để coi là trend đủ rõ
input double InpMaxPriceToEMA21_ATR_Mult   = 0.90;                // Không vào lệnh nếu giá đã chạy quá xa EMA21 theo ATR
input bool   InpUseAntiExhaustionFilter    = true;                // Chặn vào lệnh ở cuối sóng kéo quá mạnh
input int    InpAntiExhaustionBars         = 3;                   // Số nến dùng kiểm tra exhaustion
input double InpExhaustionBodyATR_Mult     = 1.20;                // Tổng thân nến cùng màu vượt ATR*x sẽ coi là exhaustion
input bool   InpUseAntiChaseFilter         = true;                // Chặn chase khi giá kéo xa khỏi EMA21
input double InpAntiChaseDistanceATR_Mult  = 1.00;                // Khoảng cách tối đa từ giá tới EMA21 theo ATR trước khi chặn
input bool   InpUseHybridSignalATR_SL      = true;                // Dùng Hybrid SL = max(signal candle, ATR/swing structure)
input double InpHybridSL_ATR_Mult          = 1.35;                // Phần đệm ATR cho hybrid SL
input bool   InpUseBE_ATR_Trigger          = true;                // Smart BE: thêm ngưỡng kích hoạt theo ATR
input double InpBE_ATR_Trigger_Mult        = 1.50;                // Chỉ BE khi giá chạy ít nhất ATR*x
input double InpBE_MinOffsetPrice          = 0.35;                // Offset tối thiểu khi dời BE
input bool   InpUseMinSLDistanceFloor      = true;                // Chuẩn hóa khoảng cách SL tối thiểu
input double InpMinSL_ATR_Mult             = 1.50;                // Khoảng cách SL tối thiểu theo ATR*x
input double InpMinSL_SpreadMult           = 3.00;                // Khoảng cách SL tối thiểu theo Spread*x
input double InpMinSL_FloorPrice           = 0.80;                // Sàn khoảng cách SL tối thiểu theo giá
input bool   InpUseTickVolumeBreakoutFilter= true;                // Lọc fake breakout bằng tick volume
input int    InpTickVolumeLookback         = 10;                  // Số nến lấy trung bình volume
input double InpTickVolumeMultiplier       = 1.08;                // Volume nến breakout phải >= avg*x
input bool   InpUseThreeLayerMTF           = true;                // Bật bộ lọc xu hướng 3 tầng H1/M15/khung vào
input ENUM_TIMEFRAMES InpMTF_HigherTF      = PERIOD_H1;           // Khung cấu trúc xu hướng lớn
input ENUM_TIMEFRAMES InpMTF_MidTF         = PERIOD_M15;          // Khung pullback / alignment
input int    InpMTF_PullbackLookbackBars   = 8;                   // Số nến mid TF dùng kiểm tra pullback gần đây

//--------------------------------------------------
// 06) Tín hiệu cơ bản / preset / chỉ báo gốc
//--------------------------------------------------
input group "06) Tín hiệu cơ bản / preset / chỉ báo gốc";
enum ENUM_PRESET_MODE { PRESET_AUTO=0, PRESET_MANUAL=1 };
input ENUM_PRESET_MODE InpPresetMode          = PRESET_AUTO;    // Chế độ preset tự động hoặc dùng tay
input int                InpFastMAPeriod      = 12;            // Chu kỳ MA nhanh
input int                InpSlowMAPeriod      = 26;            // Chu kỳ MA chậm
input ENUM_MA_METHOD     InpMAMethod          = MODE_EMA;      // Loại MA
input ENUM_APPLIED_PRICE InpMAPrice           = PRICE_CLOSE;   // Giá áp dụng cho MA / Bands
input int                InpRSIPeriod         = 14;            // Chu kỳ RSI
input double             InpRSIOverbought     = 58.0;          // Ngưỡng RSI quá mua
input double             InpRSIOversold       = 42.0;          // Ngưỡng RSI quá bán

//--------------------------------------------------
// 07) Chế độ Sideways / Range
//--------------------------------------------------
input group "07) Chế độ Sideways / Range";
input bool   InpEnableSidewaysMode   = true;                    // Bật nhận diện thị trường đi ngang
input int    InpADXPeriod            = 14;                      // Chu kỳ ADX
input double InpADXSidewaysMax       = 19.0;                    // ADX tối đa để coi là sideways
input int    InpBBPeriod             = 20;                      // Chu kỳ Bollinger Bands
input double InpBBDeviation          = 2.0;                     // Độ lệch chuẩn Bollinger Bands
input double InpBBTouchBufferPrice   = 1.30;                    // Buffer chạm biên BB để xác nhận range
input double InpRangeRSIBuyMax       = 46.0;                    // BUY range khi RSI <= ngưỡng này
input double InpRangeRSISellMin      = 54.0;                    // SELL range khi RSI >= ngưỡng này
input bool   InpUseMABiasFilterForRange = true;                 // Lọc range theo bias MA
input bool   InpUseBBWidthForSideways   = true;                 // Xác nhận sideways bằng độ rộng BB
input double InpMaxBBWidthPrice         = 9.0;                  // Độ rộng BB tối đa để coi là sideways

//--------------------------------------------------
// 08) Chế độ Volatility / ATR
//--------------------------------------------------
input group "08) Chế độ Volatility / ATR";
input bool   InpEnableVolatilityMode = true;                    // Bật nhận diện thị trường biến động mạnh
input int    InpATRPeriod            = 14;                      // Chu kỳ ATR
input double InpATRHighThreshold     = 6.8;                     // ATR từ mức này trở lên coi là biến động mạnh
input double InpBreakoutBufferPrice  = 0.45;                    // Buffer breakout
input double InpMomentumRSIBuyMin    = 52.0;                    // BUY momentum khi RSI >= ngưỡng này
input double InpMomentumRSISellMax   = 48.0;                    // SELL momentum khi RSI <= ngưỡng này
input bool   InpUseRSI50Cross        = true;                    // Bật tín hiệu RSI cắt 50
input double InpMinATRForRSI50Cross  = 3.8;                     // ATR tối thiểu để cho phép tín hiệu RSI cắt 50

//--------------------------------------------------
// 09) Bộ lọc thời gian & phiên giao dịch
//--------------------------------------------------
input group "09) Bộ lọc thời gian & phiên giao dịch";
input bool            InpUseTimeFilter        = false;          // Bật lọc giờ giao dịch
input int             InpTradeStartHour       = 7;              // Giờ bắt đầu giao dịch (server)
input int             InpTradeEndHour         = 22;             // Giờ kết thúc giao dịch (server)
input bool            InpEnableSessionTightening = false;       // Bật siết điều kiện trong phiên EU/US
input int             InpEUSessionStartHour      = 14;          // Giờ bắt đầu phiên EU
input int             InpEUSessionEndHour        = 17;          // Giờ kết thúc phiên EU
input int             InpUSSessionStartHour      = 19;          // Giờ bắt đầu phiên US
input int             InpUSSessionEndHour        = 22;          // Giờ kết thúc phiên US
input bool            InpTightRequireTrendAdxFloor = true;      // Khi vào chế độ siết: yêu cầu ADX theo trend floor
input double          InpTightTrendAdxBuffer       = 3.0;       // Phần đệm ADX khi vào chế độ siết
input double          InpTightBiasMinDistancePrice = 0.15;      // Khoảng cách MA tối thiểu khi vào chế độ siết
input bool            InpTightForceClosedBarSignals   = true;   // Khi siết: bắt buộc dùng nến đã đóng
input int             InpTightMinSecondsHardFloor     = 15;     // Mức sàn khoảng cách giây khi siết
input int             InpTightMinGapMinutesHardFloor  = 6;      // Mức sàn khoảng cách phút khi siết
input double          InpTightMaxATRToAllowEntry      = 0.0;    // ATR tối đa cho phép vào lệnh trong chế độ siết (0 = bỏ qua)

//--------------------------------------------------
// 10) Chặn giao dịch nâng cao: phiên / tin tức / đầu-cuối tuần
//--------------------------------------------------
input group "10) Chặn giao dịch nâng cao: phiên / tin tức / đầu-cuối tuần";
input bool   InpEnableAdvancedEntryBlocks = true;               // Bật các lớp chặn giao dịch nâng cao
input bool   InpBlockBeforeSessions       = true;               // Chặn trước phiên EU/US
input int    InpBlockBeforeEU_Min         = 30;                 // Số phút chặn trước phiên EU
input int    InpBlockBeforeUS_Min         = 30;                 // Số phút chặn trước phiên US
input bool   InpBlockAroundNews           = true;               // Chặn quanh thời điểm tin tức
input int    InpNewsBlockBefore_Min       = 30;                 // Chặn trước tin (phút)
input int    InpNewsBlockAfter_Min        = 60;                 // Chặn sau tin (phút)
input string InpHighImpactNewsTimes       = "";                 // Danh sách giờ tin mạnh, phân tách bằng dấu ';'
input bool   InpBlockAroundWeekEdges      = true;               // Chặn đầu/cuối tuần
input int    InpWeekStartBlock_Min        = 60;                 // Số phút chặn đầu tuần
input int    InpWeekEndBlock_Min          = 120;                // Số phút chặn cuối tuần

//--------------------------------------------------
// 11) Tần suất cao / tăng tốc vào lệnh
//--------------------------------------------------
input group "11) Tần suất cao / tăng tốc vào lệnh";
input bool            InpHighFrequencyMode       = false;       // Bật chế độ vào lệnh tần suất cao
input double          InpHFBiasMinDistancePrice  = 0.18;        // Khoảng cách MA tối thiểu trong chế độ HF
enum ENUM_FREQ_BOOST { FREQ_OFF=0, FREQ_MED=1, FREQ_HIGH=2 };
input ENUM_FREQ_BOOST InpFrequencyMode = FREQ_HIGH;

//================ ADAPTIVE FILTER ENGINE v5.860 =================
double GetAdaptiveMLThreshold()
{
   if(InpFrequencyMode==FREQ_HIGH) return 0.42;
   if(InpFrequencyMode==FREQ_MED)  return 0.50;
   return 0.58;
}

double GetAdaptiveAntiChase()
{
   if(InpFrequencyMode==FREQ_HIGH) return 2.20;
   if(InpFrequencyMode==FREQ_MED)  return 1.50;
   return 1.00;
}

bool UseSRFilter()
{
   if(InpFrequencyMode==FREQ_HIGH) return false;
   return true;
}

bool UseStrictMTF()
{
   if(InpFrequencyMode==FREQ_HIGH) return false;
   if(InpFrequencyMode==FREQ_MED)  return false;
   return true;
}

bool AllowNewsTrade(int impact)
{
   if(InpFrequencyMode==FREQ_HIGH) return impact>=3;
   if(InpFrequencyMode==FREQ_MED)  return impact>=2;
   return impact>=1;
}
//===============================================================


//================ TẦN SUẤT VÀO LỆNH =================
// merged into InpFrequencyMode        // Mức tăng tốc vào lệnh
input int  InpBoostSecondsMED         = 8;                      // Giảm khoảng cách giây ở mức boost MED
input int  InpBoostSecondsHIGH        = 12;                     // Giảm khoảng cách giây ở mức boost HIGH
input int  InpBoostGapMinutesMED      = 4;                      // Giảm khoảng cách phút ở mức boost MED
input int  InpBoostGapMinutesHIGH     = 1;                      // Giảm khoảng cách phút ở mức boost HIGH
input int  InpTightBoostSecondsMED    = 18;                     // Khoảng cách giây khi boost MED trong chế độ siết
input int  InpTightBoostSecondsHIGH   = 12;                     // Khoảng cách giây khi boost HIGH trong chế độ siết
input int  InpTightBoostGapMinutesMED = 8;                      // Khoảng cách phút khi boost MED trong chế độ siết
input int  InpTightBoostGapMinutesHIGH= 6;                      // Khoảng cách phút khi boost HIGH trong chế độ siết

//--------------------------------------------------
// 12) Recovery / tạm dừng sau chuỗi thua
//--------------------------------------------------
input group "12) Recovery / tạm dừng sau chuỗi thua";
input bool            InpEnableRecoveryProfitClose = true;      // Bật cơ chế đóng lệnh hồi phục lợi nhuận
input double          InpLossMarkPercent      = 12.0;           // Mức % đánh dấu lệnh đã lỗ đủ sâu để theo dõi recovery
input double          InpRecoveryProfit       = 15.0;           // Biên lợi nhuận recovery quanh mốc profit chuẩn theo lot
input int             InpMaxConsecutiveLosses = 3;              // Số lệnh thua liên tiếp tối đa trước khi tạm dừng
input int             InpPauseAfterLosses_Min = 180;            // Thời gian tạm dừng giao dịch sau chuỗi thua (phút)

//--------------------------------------------------
// 13) Thông báo
//--------------------------------------------------
input group "13) Thông báo";
input bool            InpNotifyAlert          = false;          // Bật cửa sổ Alert
input bool            InpNotifyPush           = false;          // Bật Push Notification
input bool            InpNotifyOnSignal       = true;           // Thông báo khi có quyết định tín hiệu
input bool            InpNotifyOnOrderResult  = true;           // Thông báo khi có kết quả gửi lệnh

//--------------------------------------------------
// 14) Scalping Pro - bộ lọc đa khung & kỹ thuật
//--------------------------------------------------
input group "14) Scalping Pro - bộ lọc đa khung & kỹ thuật";
input bool   InpEnableScalpingProLayer   = true;               // Bật lớp lọc Scalping Pro
input bool   InpRequireMTFTrendAlign     = true;               // Yêu cầu đồng thuận xu hướng đa khung
// DUPLICATE_REMOVED input ENUM_TIMEFRAMES InpTrendTF1        = PERIOD_H1;          // Khung xu hướng 1
// DUPLICATE_REMOVED input ENUM_TIMEFRAMES InpTrendTF2        = PERIOD_M15;         // Khung xu hướng 2
input bool   InpUseEMA21_50Filter        = true;               // Bật lọc EMA21/EMA50
input int    InpEMA21                    = 21;                 // Chu kỳ EMA nhanh
input int    InpEMA50                    = 50;                 // Chu kỳ EMA chậm
input bool   InpUseStochFilter           = true;               // Bật lọc Stochastic
input int    InpStochK                   = 5;                  // Chu kỳ %K
input int    InpStochD                   = 3;                  // Chu kỳ %D
input int    InpStochSlowing             = 3;                  // Hệ số làm chậm Stochastic
input double InpStochOverbought          = 80;                 // Ngưỡng quá mua Stochastic
input double InpStochOversold            = 20;                 // Ngưỡng quá bán Stochastic
input double InpTF_StochBuy_MinK         = 28.0;               // TREND_FOLLOW BUY: K tối thiểu khi follow trend
input double InpTF_StochBuy_CrossMinK    = 18.0;               // TREND_FOLLOW BUY: K tối thiểu khi cắt lên
input double InpTF_StochSell_MaxK        = 72.0;               // TREND_FOLLOW SELL: K tối đa khi follow trend
input double InpTF_StochSell_CrossMaxK   = 82.0;               // TREND_FOLLOW SELL: K tối đa khi cắt xuống
input bool   InpUseRSI_OBOS_Filter       = false;              // Bật lọc RSI OB/OS bổ sung
input double InpRSI_OB                   = 70.0;               // Ngưỡng RSI quá mua bổ sung
input double InpRSI_OS                   = 30.0;               // Ngưỡng RSI quá bán bổ sung
input bool   InpPreferDivergence         = false;              // Ưu tiên tín hiệu phân kỳ
input int    InpSwingLookbackBars        = 60;                 // Số nến lookback cho swing / divergence
input int    InpSwingLeftRight           = 2;                  // Độ rộng trái-phải để xác định swing
input bool   InpUsePriceActionConfirm    = false;              // Bật xác nhận price action
input double InpDojiBodyToRangeMax       = 0.18;               // Tỷ lệ tối đa thân nến/doji so với biên độ
input double InpPinbarWickBodyMin        = 1.8;                // Tỷ lệ tối thiểu râu/thân của pinbar
input bool   InpUseSRConfirm             = true;               // Bật xác nhận hỗ trợ/kháng cự
input int    InpSRLookbackBars           = 80;                 // Số nến lookback tìm S/R
input double InpSRBufferPrice            = 2.2;                // Buffer giá để xác nhận S/R
enum ENUM_SR_MODE { SR_OFF=0, SR_HARD=1, SR_SOFT=2 };
input ENUM_SR_MODE InpSRMode          = SR_SOFT;            // Chế độ xác nhận hỗ trợ/kháng cự
input int          InpSRSoft_MaxOpenCap = 1;                // Khi SR fail ở chế độ SOFT: giới hạn số lệnh tối đa
input int          InpSRSoft_ExtraGapSec = 15;              // Khi SR fail ở chế độ SOFT: cộng thêm khoảng cách giây
input int          InpSRSoft_ExtraGapMin = 1;               // Khi SR fail ở chế độ SOFT: cộng thêm khoảng cách phút
input bool   InpUseBBMeanReversionLogic  = false;              // Bật logic hồi quy về trung bình theo Bollinger Bands
input double InpBandRideMinBars          = 2;                  // Số nến tối thiểu bám band
input bool   InpUseRRStops               = true;               // Bật TP/SL theo tỷ lệ RR
input double InpRR_Min                   = 1.3;                // Tỷ lệ RR tối thiểu
input double InpSL_ATR_Mult              = 1.15;               // Hệ số ATR khi dựng SL
input double InpSL_SwingBufferPrice      = 0.45;               // Buffer swing khi dựng SL
input double InpMaxSLPriceCap            = 0.0;                // Giới hạn trần SL theo giá (0 = không giới hạn)
input double InpMaxTPPriceCap            = 0.0;                // Giới hạn trần TP theo giá (0 = không giới hạn)
input bool   InpLogAnalysisEverySignal   = true;               // Ghi log phân tích mỗi khi có tín hiệu

//--------------------------------------------------
// 15) Pyramiding an toàn theo TREND_FOLLOW
//--------------------------------------------------
input group "15) Pyramiding an toàn theo TREND_FOLLOW";
input bool   InpEnablePyramidingSafe     = false;              // Bật cơ chế nhồi lệnh an toàn
input bool   InpBlockHedgeAlways         = true;               // Luôn chặn mở lệnh ngược chiều với vị thế hiện tại
input bool   InpPyramidOnlyInTrendMode   = true;               // Chỉ cho nhồi trong chế độ trend
input bool   InpPyramidRequireProfit     = true;               // Chỉ nhồi khi lệnh trước đã có lời
input double InpPyramidMinProfitPrice    = 2.6;                // Mức lời tối thiểu để cho phép nhồi
input bool   InpPyramidRequireTrailMoved = true;               // Chỉ nhồi khi SL của lệnh trước đã được kéo
input double InpPyramidMinGapPrice       = 1.8;                // Khoảng cách giá tối thiểu giữa 2 lệnh cùng chiều
input double InpPyramidMinGapAtrMult     = 0.30;               // Khoảng cách tối thiểu theo ATR
input int    InpPyramidMaxAddsPerTrend   = 1;                  // Số lệnh nhồi tối đa cho mỗi xu hướng

//--------------------------------------------------
// 16) DivBOS - Phân kỳ + phá cấu trúc
//--------------------------------------------------
input group "16) DivBOS - Phân kỳ + phá cấu trúc";
input bool   InpEnableDivBOS             = true;               // Bật module DivBOS
input int    InpDivBOS_LookbackBars      = 140;                // Số nến lookback tìm setup DivBOS
input int    InpDivBOS_LeftRight         = 2;                  // Độ rộng trái-phải để xác định swing DivBOS
input double InpDivBOS_MinRSIDiff        = 3.0;                // Chênh lệch RSI tối thiểu để xác nhận phân kỳ
input double InpDivBOS_MinGapATRMult     = 0.35;               // Khoảng cách tối thiểu theo ATR để chờ break
input int    InpDivBOS_ExpireBars        = 18;                 // Số nến hết hạn setup DivBOS
input bool   InpDivBOS_ClosedBreak       = true;               // Chỉ xác nhận break khi nến đã đóng
input bool   InpDivBOS_ADXFilter         = true;               // Lọc DivBOS theo ADX
input double InpDivBOS_ADXMax            = 32.0;               // ADX tối đa cho phép đối với setup DivBOS

//--------------------------------------------------
// 17) PRO nâng cấp thực chiến
//--------------------------------------------------
input group "17) PRO nâng cấp thực chiến";
input bool   InpEnableDrawdownGuard      = true;               // Bật bảo vệ drawdown theo Equity
input double InpDrawdownWarnPercent      = 8.0;                // Từ mức DD này bắt đầu giảm khối lượng
input double InpDrawdownPausePercent     = 12.0;               // Từ mức DD này tạm dừng mở lệnh mới
input int    InpDrawdownPauseHours       = 24;                 // Số giờ tạm dừng khi DD vượt ngưỡng
input double InpDrawdownLotReducePercent = 50.0;               // Giảm % lot khi DD >= warn
input bool   InpEnablePartialClose       = true;               // Bật chốt 1 phần vị thế
input double InpPartialClose_RR          = 1.00;               // Chốt 1 phần khi đạt RR này
input double InpPartialClose_Fraction    = 0.50;               // Tỷ lệ khối lượng đóng bớt
input double InpPartialClose_MinLot      = 0.01;               // Khối lượng tối thiểu còn lại sau partial
input bool   InpEnableVolatilityTPAdjust = true;               // Điều chỉnh TP theo mức biến động hiện tại
input double InpVolatilityTPFactor       = 0.35;               // Hệ số nới RR/TP theo ATR regime
input double InpVolatilityTPCapMult      = 1.35;               // Trần hệ số nhân RR/TP theo ATR regime
input bool   InpEnableFibTPGuide         = true;               // Pha TP với mục tiêu Fibonacci của swing gần nhất
input int    InpFibSwingLookbackBars     = 36;                 // Lookback tìm swing gần nhất cho Fib TP
input double InpFibTPBlend               = 0.35;               // Tỷ lệ pha base TP với Fib TP
input bool   InpEnableSessionAdaptiveThresholds = true;        // Tự thích nghi độ chặt theo phiên giao dịch
input double InpAsiaSessionLoosenFactor  = 0.92;               // Phiên chậm: nới nhẹ ngưỡng trend/volume
input double InpLondonNYSessionTightFactor = 1.05;             // Phiên sôi động: siết nhẹ ngưỡng tránh fakeout

//--------------------------------------------------
// 18) PRO nâng cấp AI-safe / tin tức / thích nghi M5
//--------------------------------------------------
input group "18) PRO AI-safe / News / M5 Adaptive";
input bool   InpUseMT5DynamicNewsFilter   = true;                // Dùng lịch kinh tế MT5 để chặn tin động nếu terminal hỗ trợ
input string InpDynamicNewsCurrencies     = "USD";              // Danh sách tiền tệ cần theo dõi, ví dụ: USD;EUR
input int    InpDynamicNewsLookahead_Min  = 120;                 // Quét tin sắp tới trong N phút
input int    InpDynamicNewsBefore_Min     = 30;                  // Chặn trước tin mạnh
input int    InpDynamicNewsAfter_Min      = 45;                  // Chặn sau tin mạnh
input int    InpDynamicNewsMinImportance  = 2;                   // 0=low,1=medium,2=high
input string InpDynamicNewsKeywords       = "CPI;NFP;FOMC;FED;Powell;PCE;PMI;Payrolls;Inflation;Rate"; // Từ khóa tin ưu tiên chặn
input bool   InpUseProbabilisticMLFilter  = true;                // Bộ lọc xác suất kiểu ML an toàn, không phụ thuộc dịch vụ ngoài
input double InpMLScoreThreshold_Buy      = 0.58;               // Ngưỡng xác suất BUY tối thiểu
input double InpMLScoreThreshold_Sell     = 0.58;               // Ngưỡng xác suất SELL tối thiểu
input double InpMLTrendWeight             = 0.24;               // Trọng số xu hướng trong xác suất
input double InpMLMomentumWeight          = 0.18;               // Trọng số momentum
input double InpMLVolWeight               = 0.12;               // Trọng số volume / breakout
input double InpMLMTFWeight               = 0.18;               // Trọng số đồng thuận MTF
input double InpMLRiskWeight              = 0.14;               // Trọng số an toàn entry
input double InpMLPAWeight                = 0.14;               // Trọng số price action / HA / Ichimoku
input bool   InpUseIchimokuBiasFilter     = true;               // Bổ sung cổng Ichimoku cho BUY/SELL
input int    InpIchimokuTenkan            = 9;                  // Ichimoku Tenkan
input int    InpIchimokuKijun             = 26;                 // Ichimoku Kijun
input int    InpIchimokuSenkouB           = 52;                 // Ichimoku Senkou Span B
input bool   InpUseHeikenAshiConfirm      = true;               // Xác nhận nến Heiken Ashi giảm nhiễu M5
input int    InpHeikenAshiLookback        = 3;                  // Số nến HA dùng xác nhận
input bool   InpUseKeltnerLowATRMode      = true;               // Khi ATR thấp, bổ sung logic range theo Keltner
input double InpLowATRRangeThreshold      = 3.8;                // ATR thấp thì bật logic Keltner mean-reversion
input double InpKeltnerATRMult            = 1.25;               // Bề rộng Keltner dựa ATR
input double InpKeltnerRangeBuyRSIMax     = 42.0;               // RSI tối đa cho BUY range ở low ATR
input double InpKeltnerRangeSellRSIMin    = 58.0;               // RSI tối thiểu cho SELL range ở low ATR
input bool   InpEnableBacktestCSVExport   = false;              // Ghi CSV giao dịch khi backtest / forward test
input string InpBacktestCSVFileName       = "AutoConditionsEA_XAU_v4236_trades.csv"; // Tên file CSV xuất giao dịch


input bool   InpUseMLFilter            = true;   // nếu muốn giữ ML
input bool   InpUseFibTP               = true;
//==================== Indicator handles ====================//
int hFastMA = INVALID_HANDLE;
int hSlowMA = INVALID_HANDLE;
int hRSI    = INVALID_HANDLE;
int hADX    = INVALID_HANDLE;
int hBands  = INVALID_HANDLE;
int hEMA21_TF = INVALID_HANDLE;
int hEMA50_TF = INVALID_HANDLE;
int hEMA21_TF1= INVALID_HANDLE;
int hEMA50_TF1= INVALID_HANDLE;
int hEMA21_TF2= INVALID_HANDLE;
int hEMA50_TF2= INVALID_HANDLE;
int hStoch    = INVALID_HANDLE;
int hIchimoku = INVALID_HANDLE;

//==================== Runtime state ====================//
datetime lastBarTime = 0;
datetime lastEntryAttemptTime = 0;
datetime gLastOpenTimeThisEA = 0;

datetime gLastAnalysisBarTime = 0;
string   gLastAnalysisKey     = "";
datetime gLastBlockLogBarTime = 0;
string   gLastBlockLogReason  = "";

string gInstanceId = "";

datetime gTradePauseUntil = 0;
int      gConsecutiveLosses = 0;
int      gRecentSpreads[];
datetime gDrawdownPauseUntil = 0;
double   gPeakBalance = 0.0;
double   gPeakEquity  = 0.0;
ulong    gPartialTickets[];
bool     gBacktestCSVInitialized = false;

//==================== Effective parameters ====================//
int    gFastMAPeriod, gSlowMAPeriod, gRSIPeriod;
double gRSIOverbought, gRSIOversold;

bool   gTradeOnNewBar, gLogNoSignal, gVerboseLogs;
int    gMinSecondsBetweenEntries;

double gFixedLot;

double gStopLossStepPrice, gTakeProfitStepPrice;
int    gSlippagePoints;

bool   gUseMaxSpread;
int    gMaxSpreadPoints;

bool   gUseTrailingStop;
double gTrailStartPrice, gTrailStepPrice;

bool   gEnableSidewaysMode;
int    gADXPeriod;
double gADXSidewaysMax;
int    gBBPeriod;
double gBBDeviation;
double gRangeRSIBuyMax;
double gRangeRSISellMin;
double gBBTouchBufferPrice;

bool   gEnableVolatilityMode;
int    gATRPeriod;
double gATRHighThreshold;
double gBreakoutBufferPrice;
double gMomentumRSIBuyMin;
double gMomentumRSISellMax;
bool   gUseRSI50Cross;
double gMinATRForRSI50Cross;

//==================== Runtime overrides ====================//
bool   gHighFrequencyMode = false;
bool   gUseClosedBarSignals = true;
int    gMinMinutesBetweenPositions = 3;

bool   gUseTrendAdxFloor = true;
double gTrendAdxBuffer   = 2.0;
double gBiasMinDistancePrice = 0.0;

enum ENUM_TREND_MODE { TREND_PULLBACK=0, TREND_FOLLOW=1 };
ENUM_TREND_MODE gTrendMode = TREND_PULLBACK;

int  eMinSecondsBetweenEntries = 10;
int  eMinMinutesBetweenPositions = 3;
bool eTightSession = false;

//==================== Close-reason tracking ====================//
ulong  gTrailTickets[];
double gTrailLastSL[];

ulong  gCloseReqTickets[];
string gCloseReqReason[];

//==================== Recovery tracking ====================//
ulong gRecTickets[];
int   gRecLossCount[];
bool  gRecArmedLoss2[];

//==================== DivBOS runtime ====================//
struct DivBOSSetup
{
   bool   active;
   int    dir;           // +1 bullish => BUY on BOS, -1 bearish => SELL on BOS
   double refHigh;
   double refLow;
   datetime bornBarTime;
};
DivBOSSetup gDivBOS;
datetime gLastDivBOSBar = 0;

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES CalcTF()
{
   if(InpTimeframe == PERIOD_CURRENT) return (ENUM_TIMEFRAMES)_Period;
   return InpTimeframe;
}
string ChartTFString(){ return EnumToString((ENUM_TIMEFRAMES)_Period); }

string Prefix()
{
   return StringFormat("",
                       gInstanceId, InpMagicNumber, _Symbol, ChartTFString(), EnumToString(CalcTF()));
}
//==================== LOGGING (anti-spam) ====================//
string gLastDiagMsg = "";

void LogOnce(const string msg)
{
   if(!InpVerboseLogs) return;
   if(msg == gLastDiagMsg) return;
   gLastDiagMsg = msg;
   Print(Prefix(), " ", msg);
}

void LogTag(const string tag, const string msg)
{
   // Always print for essential events
   Print(Prefix(), " [", tag, "] ", msg);
}

// Diagnostic log (throttled)
void Log(const string msg){ LogOnce(msg); }

string HHMM(const datetime t)
{
   if(t <= 0) return "--:--";
   return TimeToString(t, TIME_MINUTES);
}

datetime NextAllowedTradeTime_PreSession()
{
   MqlDateTime mt;
   TimeToStruct(TimeCurrent(), mt);

   int nowMin = mt.hour * 60 + mt.min;
   int euStartMin = InpEUSessionStartHour * 60;
   int usStartMin = InpUSSessionStartHour * 60;

   datetime now = TimeCurrent();
   datetime today0 = now - (mt.hour * 3600 + mt.min * 60 + mt.sec);

   datetime euStart = today0 + euStartMin * 60;
   datetime usStart = today0 + usStartMin * 60;

   bool inEUPre = false, inUSPre = false;

   if(InpBlockBeforeEU_Min > 0)
   {
      int from = euStartMin - InpBlockBeforeEU_Min;
      if(from < 0) from += 24 * 60;

      if(from <= euStartMin) inEUPre = (nowMin >= from && nowMin < euStartMin);
      else                   inEUPre = (nowMin >= from || nowMin < euStartMin);
   }

   if(InpBlockBeforeUS_Min > 0)
   {
      int from = usStartMin - InpBlockBeforeUS_Min;
      if(from < 0) from += 24 * 60;

      if(from <= usStartMin) inUSPre = (nowMin >= from && nowMin < usStartMin);
      else                   inUSPre = (nowMin >= from || nowMin < usStartMin);
   }

   if(inEUPre) return euStart;
   if(inUSPre) return usStart;
   return 0;
}

datetime NextAllowedTradeTime_News()
{
   if(!InpBlockAroundNews) return 0;

   string src = InpHighImpactNewsTimes;
   string parts[];
   int n = StringSplit(src, ';', parts);
   if(n <= 0) return 0;

   datetime now = TimeCurrent();
   int afterSec = MathMax(InpNewsBlockAfter_Min, 0) * 60;
   int beforeSec = MathMax(InpNewsBlockBefore_Min, 0) * 60;

   for(int i = 0; i < n; i++)
   {
      string p = parts[i];
      StringTrimLeft(p);
      StringTrimRight(p);
      if(p == "") continue;

      datetime newsTime = StringToTime(p);
      if(newsTime <= 0) continue;

      if(now >= (newsTime - beforeSec) && now <= (newsTime + afterSec))
         return (newsTime + afterSec);
   }

   return 0;
}

datetime NextAllowedTradeTime_TimeFilter()
{
   if(!InpUseTimeFilter) return 0;

   MqlDateTime mt;
   TimeToStruct(TimeCurrent(), mt);

   datetime now = TimeCurrent();
   datetime today0 = now - (mt.hour * 3600 + mt.min * 60 + mt.sec);

   int startMin = InpTradeStartHour * 60;
   int endMin   = InpTradeEndHour * 60;
   int nowMin   = mt.hour * 60 + mt.min;

   if(InpTradeStartHour <= InpTradeEndHour)
   {
      if(nowMin < startMin) return today0 + startMin * 60;
      if(nowMin >= endMin)  return today0 + 24 * 3600 + startMin * 60;
      return 0;
   }
   else
   {
      if(nowMin >= startMin || nowMin < endMin) return 0;
      return today0 + startMin * 60;
   }
}

void LogBlockedOnce(const string reasonText)
{
   if(!InpEnableBlockLogs) return;

   datetime barTime = GetBarOpenTime(CalcTF(), 0);
   if(barTime == 0) barTime = TimeCurrent();

   if(gLastBlockLogBarTime == barTime && gLastBlockLogReason == reasonText)
      return;

   gLastBlockLogBarTime = barTime;
   gLastBlockLogReason  = reasonText;

   Print(Prefix(), " Không vào lệnh do: ", reasonText);
}

void LogBlockedOnceWithRetry(const string reasonText, const datetime retryTime)
{
   string msg = reasonText;
   if(retryTime > 0)
      msg += ", giờ vào lệnh lại " + HHMM(retryTime);

   LogBlockedOnce(msg);
}

void Notify(const string msg)
{
   if(InpNotifyAlert) Alert(msg);
   if(InpNotifyPush)  SendNotification(msg);
   // no Print here (keep logs clean)
}


bool IsTrendFollowContext(const string modeTag)
{
   return (modeTag=="TREND" && gTrendMode==TREND_FOLLOW);
}

//+------------------------------------------------------------------+
//| Arrays helpers                                                   |
//+------------------------------------------------------------------+
int FindTicketIndex(const ulong &arrTickets[], ulong ticket)
{
   int n = ArraySize(arrTickets);
   for(int i=0;i<n;i++) if(arrTickets[i] == ticket) return i;
   return -1;
}
void TrailMarkSet(ulong ticket, double newSL)
{
   int idx = FindTicketIndex(gTrailTickets, ticket);
   if(idx < 0)
   {
      int n = ArraySize(gTrailTickets);
      ArrayResize(gTrailTickets, n+1);
      ArrayResize(gTrailLastSL, n+1);
      gTrailTickets[n] = ticket;
      gTrailLastSL[n]  = newSL;
   }
   else gTrailLastSL[idx] = newSL;
}
void TrailMarkRemove(ulong ticket)
{
   int idx = FindTicketIndex(gTrailTickets, ticket);
   if(idx < 0) return;

   int n = ArraySize(gTrailTickets);
   if(n <= 1)
   {
      ArrayResize(gTrailTickets, 0);
      ArrayResize(gTrailLastSL, 0);
      return;
   }
   gTrailTickets[idx] = gTrailTickets[n-1];
   gTrailLastSL[idx]  = gTrailLastSL[n-1];
   ArrayResize(gTrailTickets, n-1);
   ArrayResize(gTrailLastSL, n-1);
}
void CloseReqSet(ulong ticket, const string reason)
{
   int idx = FindTicketIndex(gCloseReqTickets, ticket);
   if(idx < 0)
   {
      int n = ArraySize(gCloseReqTickets);
      ArrayResize(gCloseReqTickets, n+1);
      ArrayResize(gCloseReqReason, n+1);
      gCloseReqTickets[n] = ticket;
      gCloseReqReason[n]  = reason;
   }
   else gCloseReqReason[idx] = reason;
}
void CloseReqRemove(ulong ticket)
{
   int idx = FindTicketIndex(gCloseReqTickets, ticket);
   if(idx < 0) return;

   int n = ArraySize(gCloseReqTickets);
   if(n <= 1)
   {
      ArrayResize(gCloseReqTickets, 0);
      ArrayResize(gCloseReqReason, 0);
      return;
   }
   gCloseReqTickets[idx] = gCloseReqTickets[n-1];
   gCloseReqReason[idx]  = gCloseReqReason[n-1];
   ArrayResize(gCloseReqTickets, n-1);
   ArrayResize(gCloseReqReason, n-1);
}
void PartialMarkSet(ulong ticket)
{
   if(FindTicketIndex(gPartialTickets, ticket) >= 0) return;
   int n = ArraySize(gPartialTickets);
   ArrayResize(gPartialTickets, n+1);
   gPartialTickets[n] = ticket;
}
bool PartialMarkHas(ulong ticket)
{
   return (FindTicketIndex(gPartialTickets, ticket) >= 0);
}
void PartialMarkRemove(ulong ticket)
{
   int idx = FindTicketIndex(gPartialTickets, ticket);
   if(idx < 0) return;
   int n = ArraySize(gPartialTickets);
   if(n <= 1)
   {
      ArrayResize(gPartialTickets, 0);
      return;
   }
   gPartialTickets[idx] = gPartialTickets[n-1];
   ArrayResize(gPartialTickets, n-1);
}

// Recovery arrays
void RecEnsure(ulong ticket)
{
   int idx = FindTicketIndex(gRecTickets, ticket);
   if(idx >= 0) return;

   int n = ArraySize(gRecTickets);
   ArrayResize(gRecTickets, n+1);
   ArrayResize(gRecLossCount, n+1);
   ArrayResize(gRecArmedLoss2, n+1);

   gRecTickets[n]   = ticket;
   gRecLossCount[n] = 0;
   gRecArmedLoss2[n]= false;
}
int RecGetLossCount(ulong ticket)
{
   int idx = FindTicketIndex(gRecTickets, ticket);
   if(idx < 0) return 0;
   return gRecLossCount[idx];
}
bool RecGetArmedLoss2(ulong ticket)
{
   int idx = FindTicketIndex(gRecTickets, ticket);
   if(idx < 0) return false;
   return gRecArmedLoss2[idx];
}
void RecSetLossCount(ulong ticket, int c)
{
   RecEnsure(ticket);
   int idx = FindTicketIndex(gRecTickets, ticket);
   if(idx >= 0) gRecLossCount[idx] = c;
}
void RecSetArmedLoss2(ulong ticket, bool v)
{
   RecEnsure(ticket);
   int idx = FindTicketIndex(gRecTickets, ticket);
   if(idx >= 0) gRecArmedLoss2[idx] = v;
}
void RecRemove(ulong ticket)
{
   int idx = FindTicketIndex(gRecTickets, ticket);
   if(idx < 0) return;

   int n = ArraySize(gRecTickets);
   if(n <= 1)
   {
      ArrayResize(gRecTickets, 0);
      ArrayResize(gRecLossCount, 0);
      ArrayResize(gRecArmedLoss2, 0);
      return;
   }
   gRecTickets[idx]   = gRecTickets[n-1];
   gRecLossCount[idx] = gRecLossCount[n-1];
   gRecArmedLoss2[idx]= gRecArmedLoss2[n-1];

   ArrayResize(gRecTickets, n-1);
   ArrayResize(gRecLossCount, n-1);
   ArrayResize(gRecArmedLoss2, n-1);
}

//+------------------------------------------------------------------+
//| Time windows                                                     |
//+------------------------------------------------------------------+
bool HourInWindow(int hour, int startH, int endH)
{
   if(startH <= endH) return (hour >= startH && hour < endH);
   return (hour >= startH || hour < endH);
}
bool IsTradingTime()
{
   if(!InpUseTimeFilter) return true;
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   return HourInWindow(t.hour, InpTradeStartHour, InpTradeEndHour);
}
bool IsTightSessionNow()
{
   if(!InpEnableSessionTightening) return false;
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   bool eu = HourInWindow(t.hour, InpEUSessionStartHour, InpEUSessionEndHour);
   bool us = HourInWindow(t.hour, InpUSSessionStartHour, InpUSSessionEndHour);
   return (eu || us);
}
bool IsLondonNYSessionNow()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   bool eu = HourInWindow(t.hour, InpEUSessionStartHour, InpEUSessionEndHour);
   bool us = HourInWindow(t.hour, InpUSSessionStartHour, InpUSSessionEndHour);
   return (eu || us);
}
bool IsAsiaLikeSessionNow()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   return (!IsLondonNYSessionNow() && (t.hour >= 0 && t.hour < 8));
}
double SessionThresholdFactor()
{
   if(!InpEnableSessionAdaptiveThresholds) return 1.0;
   if(IsLondonNYSessionNow()) return MathMax(InpLondonNYSessionTightFactor, 0.80);
   if(IsAsiaLikeSessionNow()) return MathMax(InpAsiaSessionLoosenFactor, 0.70);
   return 1.0;
}
void UpdateDrawdownPeaks()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(bal > gPeakBalance) gPeakBalance = bal;
   if(eq  > gPeakEquity ) gPeakEquity  = eq;
   if(gPeakBalance <= 0.0) gPeakBalance = bal;
   if(gPeakEquity  <= 0.0) gPeakEquity  = eq;
}
double CurrentDrawdownPercent()
{
   UpdateDrawdownPeaks();
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(gPeakEquity <= 0.0 || eq <= 0.0) return 0.0;
   return MathMax(0.0, (gPeakEquity - eq) / gPeakEquity * 100.0);
}
void UpdateDrawdownPauseState()
{
   if(!InpEnableDrawdownGuard) return;
   UpdateDrawdownPeaks();
   double dd = CurrentDrawdownPercent();
   if(dd >= MathMax(InpDrawdownPausePercent, InpDrawdownWarnPercent))
   {
      datetime until = TimeCurrent() + (datetime)(MathMax(InpDrawdownPauseHours, 1) * 3600);
      if(until > gDrawdownPauseUntil)
         gDrawdownPauseUntil = until;
   }
   else if(gDrawdownPauseUntil > 0 && TimeCurrent() >= gDrawdownPauseUntil && dd < (InpDrawdownPausePercent * 0.70))
   {
      gDrawdownPauseUntil = 0;
   }
}
bool IsTradePausedByDrawdown(string &why)
{
   why = "";
   if(!InpEnableDrawdownGuard) return false;
   UpdateDrawdownPauseState();
   double dd = CurrentDrawdownPercent();
   if(gDrawdownPauseUntil > 0 && TimeCurrent() < gDrawdownPauseUntil && dd >= MathMax(InpDrawdownWarnPercent, 0.1))
   {
      why = StringFormat("DrawdownPause active until %s (DD=%.2f%%)",
                         TimeToString(gDrawdownPauseUntil, TIME_DATE|TIME_MINUTES), dd);
      return true;
   }
   return false;
}
double EffectiveLotMultiplierByDrawdown()
{
   if(!InpEnableDrawdownGuard) return 1.0;
   double dd = CurrentDrawdownPercent();
   if(dd < MathMax(InpDrawdownWarnPercent, 0.1)) return 1.0;
   double reduce = Clamp01Range(MathMax(InpDrawdownLotReducePercent, 0.0) / 100.0, 0.0, 1.0);
   return MathMax(0.10, 1.0 - reduce);
}
string Trim(const string s0)
{
   string s = s0;
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
}

// --- Advanced Entry Blocks helpers ---
bool ParseNewsTimes(const string src, datetime &arr[])
{
   ArrayResize(arr, 0);
   string s = Trim(src);
   if(s == "") return true;

   string parts[];
   int n = StringSplit(s, ';', parts);
   if(n <= 0) return true;

   for(int i=0;i<n;i++)
   {
      string p = Trim(parts[i]);
      if(p == "") continue;

      datetime dt = StringToTime(p);
      if(dt <= 0) continue;

      int k = ArraySize(arr);
      ArrayResize(arr, k+1);
      arr[k] = dt;
   }
   return true;
}
bool IsInNewsBlackoutWindow(const datetime now)
{
   if(!InpBlockAroundNews) return false;

   static datetime newsArr[];
   static string   cached = "";
   if(cached != InpHighImpactNewsTimes)
   {
      cached = InpHighImpactNewsTimes;
      ParseNewsTimes(cached, newsArr);
   }

   int beforeSec = MathMax(InpNewsBlockBefore_Min,0) * 60;
   int afterSec  = MathMax(InpNewsBlockAfter_Min,0)  * 60;

   for(int i=0;i<ArraySize(newsArr);i++)
   {
      datetime t = newsArr[i];
      if(t <= 0) continue;
      if(now >= (t - beforeSec) && now <= (t + afterSec))
         return true;
   }
   return false;
}
bool IsInPreSessionBlock(const datetime now)
{
   if(!InpBlockBeforeSessions) return false;

   MqlDateTime t; TimeToStruct(now, t);

   if(InpBlockBeforeEU_Min > 0)
   {
      int nowMin = t.hour*60 + t.min;
      int euStartMin = InpEUSessionStartHour * 60;
      int from = euStartMin - InpBlockBeforeEU_Min;
      if(from < 0) from += 24*60;

      bool inEUPre=false;
      if(from <= euStartMin) inEUPre = (nowMin >= from && nowMin < euStartMin);
      else                   inEUPre = (nowMin >= from || nowMin < euStartMin);

      if(inEUPre) return true;
   }

   if(InpBlockBeforeUS_Min > 0)
   {
      int nowMin = t.hour*60 + t.min;
      int usStartMin = InpUSSessionStartHour * 60;
      int from = usStartMin - InpBlockBeforeUS_Min;
      if(from < 0) from += 24*60;

      bool inUSPre=false;
      if(from <= usStartMin) inUSPre = (nowMin >= from && nowMin < usStartMin);
      else                   inUSPre = (nowMin >= from || nowMin < usStartMin);

      if(inUSPre) return true;
   }

   return false;
}
bool IsInWeekEdgeBlock(const datetime now)
{
   if(!InpBlockAroundWeekEdges) return false;

   MqlDateTime t; TimeToStruct(now, t);

   if(InpWeekStartBlock_Min > 0)
   {
      if(t.day_of_week == 0) // Sunday
      {
         int nowMin = t.hour*60 + t.min;
         int endMin = 24*60;
         if(nowMin >= (endMin - InpWeekStartBlock_Min))
            return true;
      }
   }

   if(InpWeekEndBlock_Min > 0)
   {
      if(t.day_of_week == 5) // Friday
      {
         int nowMin = t.hour*60 + t.min;
         int endMin = 24*60;
         if(nowMin >= (endMin - InpWeekEndBlock_Min))
            return true;
      }
   }

   return false;
}
bool IsEntryBlockedNow(const double atr0, string &why)
{
   why = "";
   if(!InpEnableAdvancedEntryBlocks && !InpUseMT5DynamicNewsFilter) return false;

   datetime now = TimeCurrent();

   if(InpEnableAdvancedEntryBlocks)
   {
      if(IsInPreSessionBlock(now))
      { why = "Chặn trước phiên"; return true; }

      if(IsInNewsBlackoutWindow(now))
      { why = "Chặn trước/sau tin tức"; return true; }

      if(IsInWeekEdgeBlock(now))
      { why = "Chặn đầu/cuối tuần"; return true; }
   }

   string dynWhy = "";
   if(DynamicNewsBlockNow(now, dynWhy))
{
   // Frequency-aware news filtering
   if(!AllowNewsTrade(InpDynamicNewsMinImportance))
   {
      why = dynWhy + " (blocked by frequency mode)";
      return true;
   }
   // keep original block behavior
   why = dynWhy;
   return true;
}

   return false;
}

double SafeSigmoid(const double x)
{
   if(x > 50.0) return 1.0;
   if(x < -50.0) return 0.0;
   return 1.0 / (1.0 + MathExp(-x));
}

string UpperText(string s)
{
   StringToUpper(s);
   return s;
}

bool StringListContainsToken(const string listRaw, const string tokenRaw)
{
   string list = UpperText(listRaw);
   string token = UpperText(tokenRaw);
   if(token == "") return false;
   string parts[];
   int n = StringSplit(list, ';', parts);
   if(n <= 0)
   {
      return (StringFind(list, token) >= 0);
   }
   for(int i=0; i<n; ++i)
   {
      string p = parts[i];
      StringTrimLeft(p);
      StringTrimRight(p);
      if(p == token) return true;
   }
   return false;
}

bool DynamicNewsBlockNow(const datetime now, string &why)
{
   why = "";
   if(!InpUseMT5DynamicNewsFilter) return false;

   datetime from = now - (datetime)(MathMax(InpDynamicNewsBefore_Min, 0) * 60);
   datetime to   = now + (datetime)(MathMax(InpDynamicNewsLookahead_Min, MathMax(InpDynamicNewsAfter_Min, 1)) * 60);

   MqlCalendarValue values[];
   ResetLastError();
   int total = CalendarValueHistory(values, from, to, "", "");
   if(total <= 0)
      return false;

   string kw = UpperText(InpDynamicNewsKeywords);
   for(int i=0; i<total; ++i)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;

      if((int)ev.importance < MathMax(InpDynamicNewsMinImportance, 0))
         continue;

      MqlCalendarCountry ctry;
      string ccy = "";
      if(CalendarCountryById(ev.country_id, ctry))
         ccy = ctry.currency;
      if(!StringListContainsToken(InpDynamicNewsCurrencies, ccy))
         continue;

      if(kw != "")
      {
         string evName = UpperText(ev.name);
         string kws[];
         int nk = StringSplit(kw, ';', kws);
         bool kwHit = false;
         for(int k=0; k<nk; ++k)
         {
            string key = kws[k];
            StringTrimLeft(key);
            StringTrimRight(key);
            if(key != "" && StringFind(evName, key) >= 0)
            {
               kwHit = true;
               break;
            }
         }
         if(nk > 0 && !kwHit)
            continue;
      }

      long dtSec = (long)(values[i].time - now);
      long beforeSec = (long)MathMax(InpDynamicNewsBefore_Min, 0) * 60;
      long afterSec  = (long)MathMax(InpDynamicNewsAfter_Min, 0) * 60;
      if(dtSec >= -afterSec && dtSec <= beforeSec)
      {
         why = StringFormat("DynamicNewsBlock[%s][%s] at %s", ccy, ev.name, TimeToString(values[i].time, TIME_DATE|TIME_MINUTES));
         return true;
      }
   }
   return false;
}

bool HeikenAshiConfirm(const ENUM_ORDER_TYPE orderType, const ENUM_TIMEFRAMES tf, string &why)
{
   why = "";
   if(!InpUseHeikenAshiConfirm) return true;

   int need = MathMax(InpHeikenAshiLookback, 2) + 2;
   MqlRates rr[];
   ArraySetAsSeries(rr, true);
   if(CopyRates(_Symbol, tf, 0, need, rr) < need)
   {
      why = "HADataUnavailable";
      return false;
   }

   double haOpenPrev = (rr[need-1].open + rr[need-1].close) * 0.5;
   double haClosePrev = (rr[need-1].open + rr[need-1].high + rr[need-1].low + rr[need-1].close) / 4.0;
   int bullish=0, bearish=0;
   for(int i=need-2; i>=1; --i)
   {
      double haClose = (rr[i].open + rr[i].high + rr[i].low + rr[i].close) / 4.0;
      double haOpen  = (haOpenPrev + haClosePrev) * 0.5;
      if(haClose > haOpen) bullish++;
      if(haClose < haOpen) bearish++;
      haOpenPrev = haOpen;
      haClosePrev = haClose;
   }

   if(orderType == ORDER_TYPE_BUY && bullish <= bearish)
   {
      why = StringFormat("HAWeakBull(%d/%d)", bullish, bearish);
      return false;
   }
   if(orderType == ORDER_TYPE_SELL && bearish <= bullish)
   {
      why = StringFormat("HAWeakBear(%d/%d)", bearish, bullish);
      return false;
   }
   return true;
}

bool IchimokuBiasFilter(const ENUM_ORDER_TYPE orderType, const ENUM_TIMEFRAMES tf, string &why, double &tenkan, double &kijun, double &spanA, double &spanB)
{
   why = "";
   tenkan=0.0; kijun=0.0; spanA=0.0; spanB=0.0;
   if(!InpUseIchimokuBiasFilter) return true;
   if(hIchimoku == INVALID_HANDLE)
   {
      why = "IchimokuHandleInvalid";
      return false;
   }

   double b0[1], b1[1], b2[1], b3[1];
   if(CopyBuffer(hIchimoku, 0, 1, 1, b0) != 1 ||
      CopyBuffer(hIchimoku, 1, 1, 1, b1) != 1 ||
      CopyBuffer(hIchimoku, 2, 1, 1, b2) != 1 ||
      CopyBuffer(hIchimoku, 3, 1, 1, b3) != 1)
   {
      why = "IchimokuDataUnavailable";
      return false;
   }

   tenkan = b0[0]; kijun = b1[0]; spanA = b2[0]; spanB = b3[0];
   double close1 = iClose(_Symbol, tf, 1);
   double cloudTop = MathMax(spanA, spanB);
   double cloudBot = MathMin(spanA, spanB);

   if(orderType == ORDER_TYPE_BUY)
   {
      bool ok = (close1 >= cloudBot && tenkan >= kijun);
      if(!ok) why = StringFormat("IchimokuBuyFail(cl=%.2f cloudBot=%.2f tenkan=%.2f kijun=%.2f)", close1, cloudBot, tenkan, kijun);
      return ok;
   }
   else
   {
      bool ok = (close1 <= cloudTop && tenkan <= kijun);
      if(!ok) why = StringFormat("IchimokuSellFail(cl=%.2f cloudTop=%.2f tenkan=%.2f kijun=%.2f)", close1, cloudTop, tenkan, kijun);
      return ok;
   }
}

double ComputeMLProbability(const ENUM_ORDER_TYPE orderType, const ENUM_TIMEFRAMES tf, const double rsiA, const double adx0, const double atr0, string &detail)
{
   detail = "";
   double e21_1=0,e21_4=0,e50_1=0,e50_4=0;
   if(!GetEMA(hEMA21_TF,1,e21_1) || !GetEMA(hEMA21_TF,4,e21_4) || !GetEMA(hEMA50_TF,1,e50_1) || !GetEMA(hEMA50_TF,4,e50_4))
      return 0.5;

   double price1 = iClose(_Symbol, tf, 1);
   double slope = e21_1 - e21_4;
   double sep   = e21_1 - e50_1;
   double dist  = (atr0 > 0.0 ? MathAbs(price1 - e21_1) / atr0 : 0.0);
   double trendScore = 0.0;
   double momentumScore = 0.0;
   double volScore = 0.0;
   double mtfScore = 0.0;
   double riskScore = 0.0;
   double paScore = 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      trendScore = Clamp01Range((slope / MathMax(AdaptiveTrendSlopeNeed(atr0), 0.01)) * 0.5 + (sep / MathMax(AdaptiveTrendSeparationNeed(atr0),0.01)) * 0.5, 0.0, 1.0);
      momentumScore = Clamp01Range((rsiA - 45.0) / 20.0, 0.0, 1.0) * 0.6 + Clamp01Range((adx0 - 12.0) / 18.0, 0.0, 1.0) * 0.4;
   }
   else
   {
      trendScore = Clamp01Range(((-slope) / MathMax(AdaptiveTrendSlopeNeed(atr0), 0.01)) * 0.5 + ((-sep) / MathMax(AdaptiveTrendSeparationNeed(atr0),0.01)) * 0.5, 0.0, 1.0);
      momentumScore = Clamp01Range((55.0 - rsiA) / 20.0, 0.0, 1.0) * 0.6 + Clamp01Range((adx0 - 12.0) / 18.0, 0.0, 1.0) * 0.4;
   }

   long v0 = (long)iVolume(_Symbol, tf, 1);
   double avgV = 0.0;
   int vvN = MathMax(InpTickVolumeLookback, 3);
   for(int i=2;i<2+vvN;i++) avgV += (double)iVolume(_Symbol, tf, i);
   avgV /= (double)vvN;
   volScore = Clamp01Range((avgV > 0.0 ? ((double)v0 / avgV) : 1.0) / MathMax(AdaptiveTickVolumeNeedMult(atr0), 0.5), 0.0, 1.2);
int t1 = 0;
int t2 = 0;
   t1 = TrendByEMA((ENUM_TIMEFRAMES)InpTrendTF1, hEMA21_TF1, hEMA50_TF1);
   t2 = TrendByEMA((ENUM_TIMEFRAMES)InpTrendTF2, hEMA21_TF2, hEMA50_TF2);
   if(orderType == ORDER_TYPE_BUY) mtfScore = ((t1==TREND_UP)?0.5:0.0) + ((t2==TREND_UP)?0.5:0.0);
   else                           mtfScore = ((t1==TREND_DOWN)?0.5:0.0) + ((t2==TREND_DOWN)?0.5:0.0);

   riskScore = 1.0 - Clamp01Range(dist / MathMax(GetAdaptiveAntiChase(), 0.1), 0.0, 1.0);

   string haWhy="", ichiWhy=""; double tnk=0,kj=0,sa=0,sb=0;
   bool haOk = HeikenAshiConfirm(orderType, tf, haWhy);
   bool ichiOk = IchimokuBiasFilter(orderType, tf, ichiWhy, tnk, kj, sa, sb);
   paScore = (haOk?0.5:0.0) + (ichiOk?0.5:0.0);

   double raw = trendScore * MathMax(InpMLTrendWeight,0.0) +
                momentumScore * MathMax(InpMLMomentumWeight,0.0) +
                volScore * MathMax(InpMLVolWeight,0.0) +
                mtfScore * MathMax(InpMLMTFWeight,0.0) +
                riskScore * MathMax(InpMLRiskWeight,0.0) +
                paScore * MathMax(InpMLPAWeight,0.0);
   double wsum = MathMax(InpMLTrendWeight,0.0)+MathMax(InpMLMomentumWeight,0.0)+MathMax(InpMLVolWeight,0.0)+MathMax(InpMLMTFWeight,0.0)+MathMax(InpMLRiskWeight,0.0)+MathMax(InpMLPAWeight,0.0);
   if(wsum <= 0.0) wsum = 1.0;
   double centered = (raw / wsum - 0.5) * 4.0;
   double prob = SafeSigmoid(centered);

   detail = StringFormat("MLProb=%.2f trend=%.2f mom=%.2f vol=%.2f mtf=%.2f risk=%.2f pa=%.2f", prob, trendScore, momentumScore, volScore, mtfScore, riskScore, paScore);
   return prob;
}

bool MLProbabilityGate(const ENUM_ORDER_TYPE orderType, const ENUM_TIMEFRAMES tf, const double rsiA, const double adx0, const double atr0, string &why)
{
   why = "";
   if(!InpUseProbabilisticMLFilter) return true;
   string detail = "";
   double p = ComputeMLProbability(orderType, tf, rsiA, adx0, atr0, detail);
   double th = GetAdaptiveMLThreshold();
   if(p + 1e-9 < th)
   {
      why = StringFormat("MLFilterFail(prob=%.2f<th=%.2f) %s", p, th, detail);
      return false;
   }
   why = detail;
   return true;
}

void ExportTradeCSV(const string stage, const ulong posId, const string side, const double vol, const double price, const double profit, const string reason, const string comment)
{
   if(!InpEnableBacktestCSVExport) return;
   int flags = FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE;
   int fh = FileOpen(InpBacktestCSVFileName, flags, ';');
   if(fh == INVALID_HANDLE) return;
   if(!gBacktestCSVInitialized || FileSize(fh) == 0)
   {
      FileSeek(fh, 0, SEEK_END);
      FileWrite(fh, "time", "symbol", "stage", "position_id", "side", "volume", "price", "profit", "reason", "comment");
      gBacktestCSVInitialized = true;
   }
   FileSeek(fh, 0, SEEK_END);
   FileWrite(fh, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), _Symbol, stage, (string)posId, side, DoubleToString(vol,2), DoubleToString(price,_Digits), DoubleToString(profit,2), reason, comment);
   FileClose(fh);
}

//+------------------------------------------------------------------+
//| Positions helpers                                                |
//+------------------------------------------------------------------+
int CountOpenPositionsThisEA()
{
   int cnt=0;
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber) continue;
      cnt++;
   }
   return cnt;
}
int CountOpenPositionsByTypeThisEA(const long posType)
{
   int cnt=0;
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber) continue;

      long t = (long)PositionGetInteger(POSITION_TYPE);
      if(t == posType) cnt++;
   }
   return cnt;
}
bool HasOppositePositionThisEA(const ENUM_ORDER_TYPE orderType)
{
   long wantPosType = (orderType==ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
   long oppPosType  = (wantPosType==POSITION_TYPE_BUY ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);
   return (CountOpenPositionsByTypeThisEA(oppPosType) > 0);
}
datetime GetLatestPositionOpenTimeThisEA()
{
   datetime latest = 0;
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber) continue;

      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t > latest) latest = t;
   }
   return latest;
}
double GetLatestPositionEntryPriceThisEA()
{
   datetime latest = 0;
   double   price  = 0.0;

   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber) continue;

      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= latest)
      {
         latest = t;
         price  = PositionGetDouble(POSITION_PRICE_OPEN);
      }
   }
   return price;
}
double GetBestProfitPriceDeltaSameDir(const ENUM_ORDER_TYPE orderType)
{
   long wantPosType = (orderType==ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double best = -1e9;
   bool found=false;

   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber) continue;

      long t = (long)PositionGetInteger(POSITION_TYPE);
      if(t != wantPosType) continue;

      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double dp = 0.0;
      if(wantPosType == POSITION_TYPE_BUY)  dp = (bid - openP);
      else                                 dp = (openP - ask);

      if(!found || dp > best){ best=dp; found=true; }
   }

   if(!found) return 0.0;
   return best;
}
bool AnySameDirHasSLOrTrailed(const ENUM_ORDER_TYPE orderType)
{
   long wantPosType = (orderType==ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber) continue;

      long t = (long)PositionGetInteger(POSITION_TYPE);
      if(t != wantPosType) continue;

      double sl = PositionGetDouble(POSITION_SL);
      if(sl > 0.0) return true;

      if(FindTicketIndex(gTrailTickets, ticket) >= 0) return true;
   }
   return false;
}
int EffectiveMaxOpen()
{
   if(InpOnePositionPerSymbol) return 1;
   int m = InpMaxOpenPositions;
   if(m < 1) m = 1;
   return m;
}
bool CanOpenMorePositions()
{
   return (CountOpenPositionsThisEA() < EffectiveMaxOpen());
}

//+------------------------------------------------------------------+
//| Min gap between positions                                        |
//+------------------------------------------------------------------+
int EffectiveMinMinutesBetweenPositions()
{
   int mins = eMinMinutesBetweenPositions;
   if(mins < 0) mins = 0;
   return mins;
}
bool CheckMinMinutesBetweenPositions()
{
   int mins = EffectiveMinMinutesBetweenPositions();
   if(mins <= 0) return true;

   datetime latestPosTime = GetLatestPositionOpenTimeThisEA();
   if(latestPosTime <= 0)
      latestPosTime = gLastOpenTimeThisEA;

   if(latestPosTime <= 0) return true;

   datetime now = TimeCurrent();
   long needSec = (long)mins * 60;
   long passed  = (long)(now - latestPosTime);

   return (passed >= needSec);
}

//+------------------------------------------------------------------+
//| Pyramiding Safe Gate                                             |
//+------------------------------------------------------------------+
bool CanPyramidSafe(const ENUM_ORDER_TYPE orderType,
                    const string modeTag,
                    const double atr0,
                    string &why)
{
   why = "";

   if(!InpEnablePyramidingSafe) return true;

   int maxOpen = EffectiveMaxOpen();
   if(maxOpen <= 1) return true;

   int total = CountOpenPositionsThisEA();
   if(total <= 0) return true;

   if(InpBlockHedgeAlways && HasOppositePositionThisEA(orderType))
   {
      why = "PyramidSafe: HedgeBlocked(oppExists)";
      return false;
   }

   if(InpPyramidOnlyInTrendMode)
   {
      if(!(modeTag=="TREND" && gTrendMode==TREND_FOLLOW))
      {
         why = "PyramidSafe: OnlyTrendFollow";
         return false;
      }
   }

   int wantPosType = (orderType==ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
   int sameDir = CountOpenPositionsByTypeThisEA(wantPosType);

   int maxAdds = MathMax(maxOpen - 1, 0);
   if(InpPyramidMaxAddsPerTrend >= 0)
      maxAdds = MathMin(maxAdds, InpPyramidMaxAddsPerTrend);

   if(sameDir >= (1 + maxAdds))
   {
      why = "PyramidSafe: MaxAddsReached";
      return false;
   }

   if(InpPyramidRequireProfit)
   {
      double bestProfitPrice = GetBestProfitPriceDeltaSameDir(orderType);
      if(bestProfitPrice < InpPyramidMinProfitPrice)
      {
         why = StringFormat("PyramidSafe: ProfitTooLow(%.2f<%.2f)", bestProfitPrice, InpPyramidMinProfitPrice);
         return false;
      }
   }

   if(InpPyramidRequireTrailMoved)
   {
      if(!AnySameDirHasSLOrTrailed(orderType))
      {
         why = "PyramidSafe: RequireSLorTrailed";
         return false;
      }
   }

   double gapNeed = InpPyramidMinGapPrice;
   if(atr0 > 0.0) gapNeed = MathMax(gapNeed, atr0 * MathMax(InpPyramidMinGapAtrMult, 0.0));

   double lastEntry = GetLatestPositionEntryPriceThisEA();
   if(lastEntry > 0.0)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double nowPx = (orderType==ORDER_TYPE_BUY ? ask : bid);
      double dist = MathAbs(nowPx - lastEntry);

      if(dist < gapNeed)
      {
         why = StringFormat("PyramidSafe: GapPriceTooSmall(%.2f<%.2f)", dist, gapNeed);
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Normalize helpers                                                |
//+------------------------------------------------------------------+
double NormalizeVolume(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   lots = MathFloor(lots / step) * step;
   if(lots < minLot) lots = minLot;

   return lots;
}
double NormalizeToTick(double price)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   int digits      = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(tickSize <= 0.0) return NormalizeDouble(price, digits);

   double ticks = MathRound(price / tickSize);
   double norm  = ticks * tickSize;
   return NormalizeDouble(norm, digits);
}
bool IsNewBar()
{
   datetime t[1];
   if(CopyTime(_Symbol, CalcTF(), 0, 1, t) != 1) return false;

   if(t[0] != lastBarTime)
   {
      lastBarTime = t[0];
      return true;
   }
   return false;
}
datetime GetBarOpenTime(ENUM_TIMEFRAMES tf, int shift)
{
   datetime t[1];
   if(CopyTime(_Symbol, tf, shift, 1, t) != 1) return 0;
   return t[0];
}

//+------------------------------------------------------------------+
//| Close opposite                                                   |
//+------------------------------------------------------------------+
void CloseOppositeIfAny(const ENUM_ORDER_TYPE orderType)
{
   if(!InpCloseOppositePositions) return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber) continue;

      long posType = (long)PositionGetInteger(POSITION_TYPE);
      bool isOpposite =
         (orderType == ORDER_TYPE_BUY  && posType == POSITION_TYPE_SELL) ||
         (orderType == ORDER_TYPE_SELL && posType == POSITION_TYPE_BUY);

      if(!isOpposite) continue;

      double vol   = PositionGetDouble(POSITION_VOLUME);
      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);

      Log(StringFormat("CloseOpposite: requesting close ticket=%I64u type=%s vol=%.2f open=%.2f SL=%.2f TP=%.2f (before new %s)",
                       ticket,
                       (posType==POSITION_TYPE_BUY?"BUY":"SELL"),
                       vol, openP, sl, tp,
                       (orderType==ORDER_TYPE_BUY?"BUY":"SELL")));

      CloseReqSet(ticket, "CloseOpposite");
      bool ok = trade.PositionClose(ticket);

      if(!ok)
         Log(StringFormat("CloseOpposite: FAILED ticket=%I64u ret=%d (%s) lastError=%d",
                          ticket, (int)trade.ResultRetcode(), trade.ResultRetcodeDescription(), _LastError));
      else
         Log(StringFormat("CloseOpposite: close request sent ticket=%I64u ret=%d (%s)",
                          ticket, (int)trade.ResultRetcode(), trade.ResultRetcodeDescription()));
   }
}

//+------------------------------------------------------------------+
//| Trade environment checks (log reason + ATR-based dynamic spread)  |
//| v4.232: dynamic cap with floor + pct                              |
//+------------------------------------------------------------------+
bool CheckTradeEnvironment(const double atr0, string &why, int &spreadPointsOut)
{
   why = "";
   spreadPointsOut = -1;

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   { why="TerminalTradeNotAllowed"; return false; }

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   { why="MQLTradeNotAllowed"; return false; }

   long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
   { why="SymbolTradeDisabled"; return false; }

   double bid=0, ask=0;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, bid) || !SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask) || bid<=0 || ask<=0)
   { why="NoBidAsk"; return false; }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int spreadPoints = (int)MathRound((ask - bid) / point);
   spreadPointsOut = spreadPoints;

   if(gUseMaxSpread)
   {
      int cap = gMaxSpreadPoints;

      if(atr0 > 0.0 && point > 0.0)
      {
         int atrPts = (int)MathRound(atr0 / point);
         int atrCap = (int)MathRound((double)atrPts * MathMax(InpSpreadAtrPct, 0.0));
         int floorCap = MathMax(InpMinSpreadCapPoints, 0);
         cap = MathMin(cap, MathMax(floorCap, atrCap));
      }

      // If ATR missing, still apply floor to avoid cap=too-low by mistake
      cap = MathMax(cap, MathMax(InpMinSpreadCapPoints, 0));

      if(spreadPoints > cap)
      {
         why = StringFormat("SpreadTooHigh(%d>%d dyn)", spreadPoints, cap);
         return false;
      }
   }

   double avgSpread = 0.0;
   if(IsSpreadAbnormalNow(spreadPoints, avgSpread))
   {
      why = StringFormat("SpreadAbnormal(%d>%.1f*%.2f)", spreadPoints, avgSpread, MathMax(InpSpreadAbnormalMultiplier,1.1));
      return false;
   }

   if(!IsTradingTime())
   {
      why="Ngoài giờ giao dịch";
      return false;
   }

   return true;
}
bool CheckStopsDistance(double price, double sl, double tp)
{
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(stopsLevel <= 0) return true;

   if(sl > 0.0)
   {
      double distPts = MathAbs(price - sl) / point;
      if(distPts + 0.0001 < stopsLevel) return false;
   }
   if(tp > 0.0)
   {
      double distPts = MathAbs(tp - price) / point;
      if(distPts + 0.0001 < stopsLevel) return false;
   }
   return true;
}

double PipSizePrice()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5) return point * 10.0;
   return point;
}

double PipsToPrice(const double pips)
{
   return MathMax(pips, 0.0) * PipSizePrice();
}

double CurrentSpreadPrice()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid) return 0.0;
   return (ask - bid);
}

double BrokerMinStopDistancePrice()
{
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(stopsLevel <= 0 || point <= 0.0) return 0.0;
   return (stopsLevel * point);
}

double ComputeMinSLDistancePrice(const ENUM_TIMEFRAMES tf,
                                 const double atr0)
{
   if(!InpUseMinSLDistanceFloor)
      return 0.0;

   double atrUse = atr0;
   if(atrUse <= 0.0)
      GetATRValueTF(tf, 1, InpATRPeriod, atrUse);

   double atrDist    = (atrUse > 0.0 ? atrUse * MathMax(InpMinSL_ATR_Mult, 0.1) : 0.0);
   double spreadDist = CurrentSpreadPrice() * MathMax(InpMinSL_SpreadMult, 0.0);
   double floorDist  = MathMax(InpMinSL_FloorPrice, 0.0);
   double brokerDist = BrokerMinStopDistancePrice();

   return MathMax(MathMax(atrDist, spreadDist), MathMax(floorDist, brokerDist));
}


void UpdateSpreadTelemetry(const int spreadPoints)
{
   if(spreadPoints < 0) return;

   int maxSamples = MathMax(InpSpreadTelemetrySamples, 5);
   int n = ArraySize(gRecentSpreads);
   if(n < maxSamples)
   {
      ArrayResize(gRecentSpreads, n + 1);
      gRecentSpreads[n] = spreadPoints;
      return;
   }

   for(int i=1; i<n; ++i)
      gRecentSpreads[i-1] = gRecentSpreads[i];
   gRecentSpreads[n-1] = spreadPoints;
}

double RecentSpreadAverage()
{
   int n = ArraySize(gRecentSpreads);
   if(n <= 0) return 0.0;

   double sum = 0.0;
   for(int i=0; i<n; ++i) sum += gRecentSpreads[i];
   return (sum / n);
}

bool IsSpreadAbnormalNow(const int spreadPoints, double &avgSpread)
{
   avgSpread = RecentSpreadAverage();
   if(!InpUseDynamicSpreadAbnormalBlock) return false;
   if(spreadPoints < 0 || avgSpread <= 0.0) return false;

   int minSamples = MathMax(MathMin(InpSpreadTelemetrySamples, 24) / 2, 5);
   if(ArraySize(gRecentSpreads) < minSamples) return false;

   double mult = MathMax(GetAdaptiveSpreadMultiplier(), 1.1);
   return ((double)spreadPoints > avgSpread * mult);
}

bool IsTradePausedByLossStreak(string &why)
{
   why = "";
   if(gTradePauseUntil <= 0) return false;

   datetime now = TimeCurrent();
   if(now >= gTradePauseUntil)
   {
      gTradePauseUntil = 0;
      gConsecutiveLosses = 0;
      return false;
   }

   why = StringFormat("LossPause active until %s after %d consecutive losses",
                      TimeToString(gTradePauseUntil, TIME_DATE|TIME_MINUTES),
                      gConsecutiveLosses);
   return true;
}

void UpdateLossPauseStateByClosedProfit(const double profit)
{
   if(profit < -1e-8)
   {
      gConsecutiveLosses++;
      if(InpMaxConsecutiveLosses > 0 && gConsecutiveLosses >= InpMaxConsecutiveLosses)
      {
         gTradePauseUntil = TimeCurrent() + (datetime)(MathMax(InpPauseAfterLosses_Min, 1) * 60);
         LogTag("START", StringFormat("LOSS_PAUSE armed: losses=%d pauseUntil=%s",
                                       gConsecutiveLosses,
                                       TimeToString(gTradePauseUntil, TIME_DATE|TIME_MINUTES)));
      }
      return;
   }

   if(profit > 1e-8)
   {
      gConsecutiveLosses = 0;
      if(gTradePauseUntil > 0 && TimeCurrent() >= gTradePauseUntil)
         gTradePauseUntil = 0;
   }
}

int SignalBarShift()
{
   int shift = (gUseClosedBarSignals ? 1 : 0);
   if(shift < 0) shift = 0;
   return shift;
}

bool EnsureSLMeetsBrokerStopLevel(const ENUM_ORDER_TYPE orderType,
                                  const double entryPrice,
                                  double &slPrice)
{
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(stopsLevel <= 0 || point <= 0.0) return true;

   double minDist = stopsLevel * point;
   if(orderType == ORDER_TYPE_BUY)
   {
      if((entryPrice - slPrice) < minDist)
         slPrice = NormalizeToTick(entryPrice - minDist);
      return (slPrice < entryPrice);
   }

   if((slPrice - entryPrice) < minDist)
      slPrice = NormalizeToTick(entryPrice + minDist);
   return (slPrice > entryPrice);
}

bool BuildSignalCandleSL(const ENUM_ORDER_TYPE orderType,
                         const ENUM_TIMEFRAMES tf,
                         const double entryPrice,
                         double &outSL,
                         double &outBufferPrice,
                         string &why)
{
   why = "";
   outSL = 0.0;
   outBufferPrice = 0.0;

   int shift = SignalBarShift();

   double sigLow  = iLow(_Symbol, tf, shift);
   double sigHigh = iHigh(_Symbol, tf, shift);

   if((sigLow <= 0.0 || sigHigh <= 0.0 || sigHigh <= sigLow) && shift == 0)
   {
      shift = 1;
      sigLow  = iLow(_Symbol, tf, shift);
      sigHigh = iHigh(_Symbol, tf, shift);
   }

   if(sigLow <= 0.0 || sigHigh <= 0.0 || sigHigh <= sigLow)
   {
      why = "SignalCandleInvalid";
      return false;
   }

   outBufferPrice = MathMax(CurrentSpreadPrice(), PipsToPrice((double)InpSpreadBufferPips));

   if(orderType == ORDER_TYPE_BUY)
      outSL = NormalizeToTick(sigLow - outBufferPrice);
   else
      outSL = NormalizeToTick(sigHigh + outBufferPrice);

   if((orderType == ORDER_TYPE_BUY  && outSL >= entryPrice) ||
      (orderType == ORDER_TYPE_SELL && outSL <= entryPrice))
   {
      why = "SignalSLWrongSide";
      return false;
   }

   return EnsureSLMeetsBrokerStopLevel(orderType, entryPrice, outSL);
}

double EstimateLossMoneyForSL(const ENUM_ORDER_TYPE orderType,
                              const double lots,
                              const double entryPrice,
                              const double slPrice)
{
   if(lots <= 0.0 || entryPrice <= 0.0 || slPrice <= 0.0) return -1.0;

   double profit = 0.0;
   if(!OrderCalcProfit(orderType, _Symbol, lots, entryPrice, slPrice, profit))
      return -1.0;

   return MathAbs(profit);
}

double EffectiveRiskPercent()
{
   double rp = InpMaxRiskPercent;
   if(rp < 0.1) rp = 0.1;
   if(rp > 2.0) rp = 2.0;
   return rp;
}

bool ValidateRiskForFixedLot(const ENUM_ORDER_TYPE orderType,
                             const double lots,
                             const double entryPrice,
                             const double slPrice,
                             double &lossMoney,
                             double &maxLossMoney)
{
   lossMoney = -1.0;
   maxLossMoney = 0.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return false;

   maxLossMoney = balance * (EffectiveRiskPercent() / 100.0);
   lossMoney = EstimateLossMoneyForSL(orderType, lots, entryPrice, slPrice);
   if(lossMoney < 0.0) return false;

   return (lossMoney <= maxLossMoney + 1e-8);
}

double DeriveTargetRR(const double entryPrice,
                      const double baseSL,
                      const double baseTP)
{
   if(entryPrice > 0.0 && baseSL > 0.0 && baseTP > 0.0)
   {
      double risk = MathAbs(entryPrice - baseSL);
      double reward = MathAbs(baseTP - entryPrice);
      if(risk > 1e-9 && reward > 1e-9)
         return MathMax(reward / risk, 0.2);
   }

   if(InpStopLossStepPrice > 0.0 && InpTakeProfitStepPrice > 0.0)
      return MathMax(InpTakeProfitStepPrice / InpStopLossStepPrice, 0.2);

   return 2.0;
}


void ApplyBreakEvenLogic()
{
   if(!InpEnableBreakEven) return;

   int stopsLevelPts = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minStop    = (stopsLevelPts > 0 ? stopsLevelPts * point : 0.0);
   double offset     = MathMax(InpBE_OffsetPrice, 0.0);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      long type        = (long)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);
      if(openPrice <= 0.0 || tp <= 0.0 || sl <= 0.0) continue;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double totalProfitDist   = MathAbs(tp - openPrice);
      double currentProfitDist = (type == POSITION_TYPE_BUY ? (bid - openPrice) : (openPrice - ask));
      double riskDist          = MathAbs(openPrice - sl);

      if(totalProfitDist <= 0.0 || currentProfitDist <= 0.0 || riskDist <= 0.0)
         continue;

      double beByTP  = totalProfitDist * MathMax(InpBEThreshold, 0.0);
      double beByRR  = riskDist * MathMax(InpBE_RR_Trigger, 0.1);
      double beByATR = 0.0;
      if(InpUseBE_ATR_Trigger)
      {
         double atrBE = 0.0;
         if(GetATRValueTF(CalcTF(), 1, InpATRPeriod, atrBE) && atrBE > 0.0)
            beByATR = atrBE * MathMax(InpBE_ATR_Trigger_Mult, 0.1);
      }

      double beTrigger = MathMax(MathMax(beByTP, beByRR), beByATR);
      if(currentProfitDist < beTrigger)
         continue;

      double beOffset = MathMax(offset, MathMax(InpBE_MinOffsetPrice, CurrentSpreadPrice()));
      double beSL = 0.0;
      if(type == POSITION_TYPE_BUY)
         beSL = NormalizeToTick(openPrice + beOffset);
      else
         beSL = NormalizeToTick(openPrice - beOffset);

      if(type == POSITION_TYPE_BUY)
      {
         if(sl >= beSL) continue;
         if(minStop > 0.0 && (bid - beSL) < minStop) continue;
      }
      else
      {
         if(sl <= beSL) continue;
         if(minStop > 0.0 && (beSL - ask) < minStop) continue;
      }

      if(trade.PositionModify(ticket, beSL, tp))
         TrailMarkSet(ticket, beSL);
   }
}

//+------------------------------------------------------------------+
//| Stops calculation                                                |
//+------------------------------------------------------------------+
void CalcStopDistances(const string modeTag,
                       const double atr0,
                       double &slDist,
                       double &tpDist)
{
   double maxSL = gStopLossStepPrice;
   double maxTP = gTakeProfitStepPrice;

   if(InpFixStops)
   {
      slDist = maxSL;
      tpDist = maxTP;
      return;
   }

   double atr = atr0;
   if(atr <= 0.0)
      atr = (maxTP > 0.0 ? maxTP : (maxSL > 0.0 ? maxSL : 0.0));

   double slMul = 1.0, tpMul = 1.0;
   if(modeTag == "VOLATILE")
   { slMul = 1.0; tpMul = 1.35; }
   else if(modeTag == "RANGE")
   { slMul = 0.85; tpMul = 0.95; }
   else
   { slMul = 1.10; tpMul = 1.70; }

   tpDist = atr * tpMul;
   if(maxTP > 0.0) tpDist = MathMin(tpDist, maxTP);
   if(maxTP <= 0.0) tpDist = 0.0;

   double slAuto = atr * slMul;
   slDist = slAuto * 1.5;
   if(maxSL > 0.0) slDist = MathMin(slDist, maxSL);
   if(maxSL <= 0.0) slDist = 0.0;
}
void BuildStopsFromDistance(const ENUM_ORDER_TYPE orderType,
                            const double entry,
                            const double slDist,
                            const double tpDist,
                            double &sl,
                            double &tp)
{
   sl = 0.0; tp = 0.0;
   if(orderType == ORDER_TYPE_BUY)
   {
      if(slDist > 0.0) sl = NormalizeToTick(entry - slDist);
      if(tpDist > 0.0) tp = NormalizeToTick(entry + tpDist);
   }
   else
   {
      if(slDist > 0.0) sl = NormalizeToTick(entry + slDist);
      if(tpDist > 0.0) tp = NormalizeToTick(entry - tpDist);
   }
}

//==================== Indicator reads ====================//
bool ReadRSI(double &r0, double &r1, double &r2)
{
   double b[3];
   if(CopyBuffer(hRSI, 0, 0, 3, b) != 3) return false;
   r0=b[0]; r1=b[1]; r2=b[2];
   return true;
}
bool ReadMA(double &f0,double &f1,double &f2,
            double &s0,double &s1,double &s2)
{
   double f[3], s[3];
   if(CopyBuffer(hFastMA,0,0,3,f)!=3) return false;
   if(CopyBuffer(hSlowMA,0,0,3,s)!=3) return false;
   f0=f[0]; f1=f[1]; f2=f[2];
   s0=s[0]; s1=s[1]; s2=s[2];
   return true;
}
bool ReadADX(double &adx0)
{
   double b[1];
   if(CopyBuffer(hADX,0,0,1,b)!=1) return false;
   adx0 = b[0];
   return true;
}
bool ReadBands(double &up0,double &mid0,double &low0)
{
   up0=mid0=low0=0.0;

   double up[1], mid[1], low[1];
   if(CopyBuffer(hBands,0,0,1,up)!=1)  return false;
   if(CopyBuffer(hBands,1,0,1,mid)!=1) return false;
   if(CopyBuffer(hBands,2,0,1,low)!=1) return false;

   double a=up[0], b=mid[0], c=low[0];
   double mx = MathMax(a, MathMax(b,c));
   double mn = MathMin(a, MathMin(b,c));
   double md = a + b + c - mx - mn;

   up0  = mx;
   mid0 = md;
   low0 = mn;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double width = up0 - low0;

   if(!(up0 > mid0 && mid0 > low0 && width > point*0.5))
      return false;

   return true;
}
bool ReadATR(double &atr0)
{
   double b[1];
   if(CopyBuffer(hATR_regime,0,0,1,b)!=1) return false;
   atr0 = b[0];
   return true;
}
bool ReadStoch(double &k0,double &k1,double &k2,double &d0,double &d1,double &d2)
{
   if(hStoch == INVALID_HANDLE) return false;
   double kb[3], db[3];
   if(CopyBuffer(hStoch, 0, 0, 3, kb) != 3) return false;
   if(CopyBuffer(hStoch, 1, 0, 3, db) != 3) return false;
   k0=kb[0]; k1=kb[1]; k2=kb[2];
   d0=db[0]; d1=db[1]; d2=db[2];
   return true;
}

//==================== Presets ====================//
int TFMinutes(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return 1;
      case PERIOD_M2:   return 2;
      case PERIOD_M3:   return 3;
      case PERIOD_M4:   return 4;
      case PERIOD_M5:   return 5;
      case PERIOD_M6:   return 6;
      case PERIOD_M10:  return 10;
      case PERIOD_M12:  return 12;
      case PERIOD_M15:  return 15;
      case PERIOD_M20:  return 20;
      case PERIOD_M30:  return 30;
      case PERIOD_H1:   return 60;
      case PERIOD_H2:   return 120;
      case PERIOD_H3:   return 180;
      case PERIOD_H4:   return 240;
      case PERIOD_H6:   return 360;
      case PERIOD_H8:   return 480;
      case PERIOD_H12:  return 720;
      default: return 0;
   }
}

bool IsM1ToM5TF(const ENUM_TIMEFRAMES tf)
{
   return (tf==PERIOD_M1 || tf==PERIOD_M2 || tf==PERIOD_M3 || tf==PERIOD_M4 || tf==PERIOD_M5);
}

bool IsM15PlusTF(const ENUM_TIMEFRAMES tf)
{
   int mins = TFMinutes(tf);
   return (mins >= 15);
}

ENUM_TREND_MODE EffectiveTrendModeByTF()
{
   ENUM_TIMEFRAMES tf = CalcTF();
   if(!InpAutoTrendModeByTF) return gTrendMode;
   if(IsM1ToM5TF(tf)) return TREND_FOLLOW;
   return TREND_PULLBACK;
}

bool EffectiveRecoveryEnabled()
{
   if(!InpEnableRecoveryProfitClose) return false;
   if(InpDisableRecoveryOnM1ToM5 && IsM1ToM5TF(CalcTF())) return false;
   return true;
}

int EffectivePullbackRecentCrossBars()
{
   return (IsM1ToM5TF(CalcTF()) ? InpPullbackRecentCrossBars : InpM15Plus_RecentCrossBars);
}

double EffectiveTrailStartPrice()
{
   return (IsM1ToM5TF(CalcTF()) ? InpM1M5_TrailStartPrice : InpM15Plus_TrailStartPrice);
}

double EffectiveTrailStepPrice()
{
   return (IsM1ToM5TF(CalcTF()) ? InpM1M5_TrailStepPrice : InpM15Plus_TrailStepPrice);
}

double EffectiveFollowBuyRSIMin()
{
   return (IsM1ToM5TF(CalcTF()) ? InpM1M5_FollowBuyRSIMin : 50.0);
}

double EffectiveFollowSellRSIMax()
{
   return (IsM1ToM5TF(CalcTF()) ? InpM1M5_FollowSellRSIMax : 50.0);
}

double EffectivePullbackBuyRSIMax()
{
   return (IsM15PlusTF(CalcTF()) ? InpM15Plus_PullbackBuyRSIMax : MathMin(gRSIOversold + 4.0, 48.0));
}

double EffectivePullbackSellRSIMin()
{
   return (IsM15PlusTF(CalcTF()) ? InpM15Plus_PullbackSellRSIMin : MathMax(gRSIOverbought - 4.0, 52.0));
}

double EffectiveTFStochBuyMinK()
{
   return (IsM1ToM5TF(CalcTF()) ? InpM1M5_StochBuyMinK : InpTF_StochBuy_MinK);
}

double EffectiveTFStochBuyCrossMinK()
{
   return (IsM1ToM5TF(CalcTF()) ? InpM1M5_StochBuyCrossMinK : InpTF_StochBuy_CrossMinK);
}

double EffectiveTFStochSellMaxK()
{
   return (IsM1ToM5TF(CalcTF()) ? InpM1M5_StochSellMaxK : InpTF_StochSell_MaxK);
}

double EffectiveTFStochSellCrossMaxK()
{
   return (IsM1ToM5TF(CalcTF()) ? InpM1M5_StochSellCrossMaxK : InpTF_StochSell_CrossMaxK);
}
void LoadManualToEffective()
{
   gFastMAPeriod   = InpFastMAPeriod;
   gSlowMAPeriod   = InpSlowMAPeriod;
   gRSIPeriod      = InpRSIPeriod;
   gRSIOverbought  = InpRSIOverbought;
   gRSIOversold    = InpRSIOversold;

   gTradeOnNewBar  = InpTradeOnNewBar;
   gMinSecondsBetweenEntries = InpMinSecondsBetweenEntries;
   gLogNoSignal    = InpLogNoSignal;
   gVerboseLogs    = InpVerboseLogs;

   gFixedLot       = InpFixedLot;

   gStopLossStepPrice   = InpStopLossStepPrice;
   gTakeProfitStepPrice = InpTakeProfitStepPrice;
   gSlippagePoints      = InpSlippagePoints;

   gUseMaxSpread     = InpUseMaxSpread;
   gMaxSpreadPoints  = InpMaxSpreadPoints;

   gUseTrailingStop  = InpUseTrailingStop;
   gTrailStartPrice  = InpTrailStartPrice;
   gTrailStepPrice   = InpTrailStepPrice;

   gEnableSidewaysMode   = InpEnableSidewaysMode;
   gADXPeriod            = InpADXPeriod;
   gADXSidewaysMax       = InpADXSidewaysMax;
   gBBPeriod             = InpBBPeriod;
   gBBDeviation          = InpBBDeviation;
   gRangeRSIBuyMax       = InpRangeRSIBuyMax;
   gRangeRSISellMin      = InpRangeRSISellMin;
   gBBTouchBufferPrice   = InpBBTouchBufferPrice;

   gEnableVolatilityMode = InpEnableVolatilityMode;
   gATRPeriod            = InpATRPeriod;
   gATRHighThreshold     = InpATRHighThreshold;
   gBreakoutBufferPrice  = InpBreakoutBufferPrice;
   gMomentumRSIBuyMin    = InpMomentumRSIBuyMin;
   gMomentumRSISellMax   = InpMomentumRSISellMax;
   gUseRSI50Cross        = InpUseRSI50Cross;
   gMinATRForRSI50Cross  = InpMinATRForRSI50Cross;
}
void LoadPresetByTF(ENUM_TIMEFRAMES tf)
{
   int mins = TFMinutes(tf);

   gFastMAPeriod   = 12;
   gSlowMAPeriod   = 26;
   gRSIPeriod      = 14;
   gRSIOverbought  = 58.0;
   gRSIOversold    = 42.0;

   gTradeOnNewBar  = false;
   gMinSecondsBetweenEntries = 10;
   gLogNoSignal    = InpLogNoSignal;
   gVerboseLogs    = InpVerboseLogs;

   gFixedLot = InpFixedLot;

   gStopLossStepPrice   = InpStopLossStepPrice;
   gTakeProfitStepPrice = InpTakeProfitStepPrice;

   gSlippagePoints = InpSlippagePoints;

   gUseMaxSpread    = true;
   gMaxSpreadPoints = InpMaxSpreadPoints;

   gUseTrailingStop  = InpUseTrailingStop;
   gTrailStartPrice  = InpTrailStartPrice;
   gTrailStepPrice   = InpTrailStepPrice;

   gEnableSidewaysMode  = true;
   gADXPeriod           = 14;
   gADXSidewaysMax      = 20.0;
   gBBPeriod            = 20;
   gBBDeviation         = 2.0;
   gRangeRSIBuyMax      = 47.0;
   gRangeRSISellMin     = 53.0;
   gBBTouchBufferPrice  = 0.90;

   gEnableVolatilityMode = true;
   gATRPeriod            = 14;
   gATRHighThreshold     = 6.0;
   gBreakoutBufferPrice  = 0.30;
   gMomentumRSIBuyMin    = 51.5;
   gMomentumRSISellMax   = 48.5;
   gUseRSI50Cross        = true;
   gMinATRForRSI50Cross  = 3.2;

   if(mins > 0 && mins <= 5)
   {
      gFastMAPeriod = 9;
      gSlowMAPeriod = 21;
      gRSIPeriod    = 9;
      gRSIOverbought= 56.0;
      gRSIOversold  = 44.0;

      gMinSecondsBetweenEntries = 8;
      gSlippagePoints = MathMax(InpSlippagePoints, 120);
      gATRHighThreshold = 5.5;
      gMinATRForRSI50Cross = 3.0;
   }
   else if(mins >= 10 && mins <= 30)
   {
      gFastMAPeriod = 12;
      gSlowMAPeriod = 30;
      gRSIPeriod    = 14;
      gRSIOverbought= 60.0;
      gRSIOversold  = 40.0;

      gMinSecondsBetweenEntries = 10;
      gATRHighThreshold = 6.5;
      gMinATRForRSI50Cross = 3.6;
   }
   else if(mins >= 60)
   {
      gFastMAPeriod = 14;
      gSlowMAPeriod = 40;
      gRSIPeriod    = 14;
      gRSIOverbought= 62.0;
      gRSIOversold  = 38.0;

      gMinSecondsBetweenEntries = 12;
      gADXSidewaysMax = 18.0;
      gATRHighThreshold = 8.0;
      gMinATRForRSI50Cross = 4.5;
      gBBTouchBufferPrice = 0.70;
   }
}
void ApplyPreset()
{
   if(InpPresetMode == PRESET_MANUAL)
   {
      LoadManualToEffective();
      Log("Preset=MANUAL loaded.");
      return;
   }
   LoadPresetByTF(CalcTF());
   Log(StringFormat("Preset=AUTO applied for TF=%s.", EnumToString(CalcTF())));
}

//+------------------------------------------------------------------+
//| HighFrequency overrides                                           |
//+------------------------------------------------------------------+
void ApplyHighFrequencyOverrides()
{
   gHighFrequencyMode = InpHighFrequencyMode;

   gUseClosedBarSignals        = InpUseClosedBarSignals;
   gMinMinutesBetweenPositions = InpMinMinutesBetweenPositions;

   gUseTrendAdxFloor = true;
   gTrendAdxBuffer   = 2.0;
   gTrendMode        = EffectiveTrendModeByTF();

   gBiasMinDistancePrice = 0.0;

   if(!gHighFrequencyMode)
      return;

   gUseClosedBarSignals = false;
   gMinMinutesBetweenPositions = 1;
   if(gMinSecondsBetweenEntries > 2) gMinSecondsBetweenEntries = 2;

   gUseTrendAdxFloor = false;
   gTrendAdxBuffer   = 0.0;
   gTrendMode        = TREND_FOLLOW;

   gBiasMinDistancePrice = InpHFBiasMinDistancePrice;
}

//+------------------------------------------------------------------+
//| Final effective params                                            |
//+------------------------------------------------------------------+
void UpdateFinalEffectiveParams()
{
   eTightSession = (InpEnableSessionTightening && IsTightSessionNow());

   eMinSecondsBetweenEntries   = gMinSecondsBetweenEntries;
   eMinMinutesBetweenPositions = gMinMinutesBetweenPositions;

   if(InpAutoTrendModeByTF)
      gTrendMode = EffectiveTrendModeByTF();

   if(eTightSession)
   {
      if(InpTightRequireTrendAdxFloor)
         gUseTrendAdxFloor = true;

      gTrendAdxBuffer = MathMax(gTrendAdxBuffer, InpTightTrendAdxBuffer);
      gBiasMinDistancePrice = MathMax(gBiasMinDistancePrice, InpTightBiasMinDistancePrice);

      if(InpTightForceClosedBarSignals)
         gUseClosedBarSignals = true;

      eMinSecondsBetweenEntries   = MathMax(eMinSecondsBetweenEntries, 20);
      eMinMinutesBetweenPositions = MathMax(eMinMinutesBetweenPositions, 10);

      gHighFrequencyMode = false;
      gUseClosedBarSignals = true;
   }

   if(InpFrequencyMode != FREQ_OFF)
   {
      bool tight = eTightSession;

      if(InpFrequencyMode == FREQ_MED)
      {
         eMinSecondsBetweenEntries   = (tight ? MathMin(eMinSecondsBetweenEntries, InpTightBoostSecondsMED)
                                             : MathMin(eMinSecondsBetweenEntries, InpBoostSecondsMED));
         eMinMinutesBetweenPositions = (tight ? MathMin(eMinMinutesBetweenPositions, InpTightBoostGapMinutesMED)
                                             : MathMin(eMinMinutesBetweenPositions, InpBoostGapMinutesMED));
      }
      else if(InpFrequencyMode == FREQ_HIGH)
      {
         eMinSecondsBetweenEntries   = (tight ? MathMin(eMinSecondsBetweenEntries, InpTightBoostSecondsHIGH)
                                             : MathMin(eMinSecondsBetweenEntries, InpBoostSecondsHIGH));
         eMinMinutesBetweenPositions = (tight ? MathMin(eMinMinutesBetweenPositions, InpTightBoostGapMinutesHIGH)
                                             : MathMin(eMinMinutesBetweenPositions, InpBoostGapMinutesHIGH));
      }

      eMinSecondsBetweenEntries = MathMax(eMinSecondsBetweenEntries, 1);
      eMinMinutesBetweenPositions = MathMax(eMinMinutesBetweenPositions, 0);
   }

   if(eTightSession)
   {
      eMinSecondsBetweenEntries   = MathMax(eMinSecondsBetweenEntries, InpTightMinSecondsHardFloor);
      eMinMinutesBetweenPositions = MathMax(eMinMinutesBetweenPositions, InpTightMinGapMinutesHardFloor);
   }
}

//+------------------------------------------------------------------+
//| Recovery Profit Close                                             |
//+------------------------------------------------------------------+
double BaseProfitTargetForLot()
{
   double baseLot = 0.01;
   if(InpFixedLot <= 0.0) return 1.0;
   return 1.0 * (InpFixedLot / baseLot);
}
double RecoveryBandMin()
{
   double pct = MathMax(InpRecoveryProfit, 0.0) / 100.0;
   double base = BaseProfitTargetForLot();
   return base * (1.0 - pct);
}
double RecoveryBandMax()
{
   double pct = MathMax(InpRecoveryProfit, 0.0) / 100.0;
   double base = BaseProfitTargetForLot();
   return base * (1.0 + pct);
}
double LossMarkThreshold()
{
   double pct = MathMax(InpLossMarkPercent, 0.0) / 100.0;
   double base = BaseProfitTargetForLot();
   return base * (1.0 + pct);
}
bool ShouldMarkLossByRule(const double profit)
{
   if(InpLossMarkPercent <= 0.0)
      return (profit < 0.0);

   double th = LossMarkThreshold();
   return (profit <= -th);
}
void ApplyRecoveryProfitClose()
{
   if(!EffectiveRecoveryEnabled()) return;

   double bandMin = RecoveryBandMin();
   double bandMax = RecoveryBandMax();
   if(bandMin <= 0.0 || bandMax <= 0.0) return;
   if(bandMax < bandMin) { double tmp=bandMin; bandMin=bandMax; bandMax=tmp; }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(gSlippagePoints);

   for(int i = PositionsTotal()-1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);

      RecEnsure(ticket);
      int  lossCount = RecGetLossCount(ticket);
      bool armed2    = RecGetArmedLoss2(ticket);

      if(lossCount == 0)
      {
         if(ShouldMarkLossByRule(profit))
         {
            RecSetLossCount(ticket, 1);
            RecSetArmedLoss2(ticket, false);
            Log(StringFormat("RecoveryTrack: Loss#1 marked ticket=%I64u profit=%.2f",
                             ticket, profit));
         }
         continue;
      }

      if(lossCount >= 2)
      {
         double tp2Need = BaseProfitTargetForLot() * 0.10;
         if(profit >= tp2Need)
         {
            Log(StringFormat("RecoveryTP2(THRESHOLD): requesting close ticket=%I64u profit=%.2f need=%.2f",
                             ticket, profit, tp2Need));
            CloseReqSet(ticket, "RecoveryTP2");
            bool ok = trade.PositionClose(ticket);

            if(!ok)
               Log(StringFormat("RecoveryTP2: FAILED ticket=%I64u ret=%d (%s) lastError=%d",
                                ticket, (int)trade.ResultRetcode(), trade.ResultRetcodeDescription(), _LastError));
            else
               Log(StringFormat("RecoveryTP2: close request sent ticket=%I64u ret=%d (%s)",
                                ticket, (int)trade.ResultRetcode(), trade.ResultRetcodeDescription()));
         }
         continue;
      }

      bool inBand = (profit + 1e-9 >= bandMin && profit - 1e-9 <= bandMax);

      if(inBand)
      {
         Log(StringFormat("RecoveryTP(IN-BAND): requesting close ticket=%I64u profit=%.2f band=[%.2f..%.2f]",
                          ticket, profit, bandMin, bandMax));

         CloseReqSet(ticket, "RecoveryTP");
         bool ok = trade.PositionClose(ticket);

         if(!ok)
            Log(StringFormat("RecoveryTP: FAILED ticket=%I64u ret=%d (%s) lastError=%d",
                             ticket, (int)trade.ResultRetcode(), trade.ResultRetcodeDescription(), _LastError));
         else
            Log(StringFormat("RecoveryTP: close request sent ticket=%I64u ret=%d (%s)",
                             ticket, (int)trade.ResultRetcode(), trade.ResultRetcodeDescription()));
         continue;
      }

      if(!armed2 && profit > 0.0 && profit < bandMin)
      {
         RecSetArmedLoss2(ticket, true);
         Log(StringFormat("RecoveryTrack: armed Loss#2 ticket=%I64u profit=%.2f (< bandMin=%.2f)",
                          ticket, profit, bandMin));
         continue;
      }

      if(armed2)
      {
         if(ShouldMarkLossByRule(profit))
         {
            RecSetLossCount(ticket, 2);
            Log(StringFormat("RecoveryTrack: Loss#2 marked ticket=%I64u profit=%.2f",
                             ticket, profit));
         }
      }
   }

   for(int k=ArraySize(gRecTickets)-1; k>=0; --k)
   {
      ulong t = gRecTickets[k];
      if(!PositionSelectByTicket(t)) RecRemove(t);
   }
}

//+------------------------------------------------------------------+
//| Trailing                                                         |
//+------------------------------------------------------------------+
void ApplyTrailing()
{
   if(!gUseTrailingStop) return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber) continue;

      long type = (long)PositionGetInteger(POSITION_TYPE);

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(InpEnableBreakEven && tp > 0.0)
      {
         double totalProfitDist   = MathAbs(tp - openPrice);
         double currentProfitDist = (type == POSITION_TYPE_BUY ? (bid - openPrice) : (openPrice - ask));
         double beTriggerDist     = totalProfitDist * MathMax(InpBEThreshold, 0.0);

         if(currentProfitDist < beTriggerDist)
            continue;

         bool beNotDone = ((type == POSITION_TYPE_BUY  && (sl == 0.0 || sl < openPrice)) ||
                           (type == POSITION_TYPE_SELL && (sl == 0.0 || sl > openPrice)));
         if(beNotDone)
            continue;
      }

      if(type == POSITION_TYPE_BUY)
      {
         double profitPrice = (bid - openPrice);
         double trailStart = EffectiveTrailStartPrice();
         double trailStep  = EffectiveTrailStepPrice();
         if(profitPrice < trailStart) continue;

         double newSL = NormalizeToTick(bid - trailStep);
         if(sl == 0.0 || newSL > sl)
         {
            bool ok = trade.PositionModify(ticket, newSL, tp);
            if(ok)
               TrailMarkSet(ticket, newSL);
            else
               Log(StringFormat("TRAILING MODIFY FAILED ticket=%I64u ret=%d (%s) lastError=%d",
                                ticket, (int)trade.ResultRetcode(), trade.ResultRetcodeDescription(), _LastError));
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double profitPrice = (openPrice - ask);
         double trailStart = EffectiveTrailStartPrice();
         double trailStep  = EffectiveTrailStepPrice();
         if(profitPrice < trailStart) continue;

         double newSL = NormalizeToTick(ask + trailStep);
         if(sl == 0.0 || newSL < sl)
         {
            bool ok = trade.PositionModify(ticket, newSL, tp);
            if(ok)
               TrailMarkSet(ticket, newSL);
            else
               Log(StringFormat("TRAILING MODIFY FAILED ticket=%I64u ret=%d (%s) lastError=%d",
                                ticket, (int)trade.ResultRetcode(), trade.ResultRetcodeDescription(), _LastError));
         }
      }
   }
}

//==================== Scalping Pro: OHLC / swings / divergence ====================//
bool ReadOHLC(ENUM_TIMEFRAMES tf, int start, int count, double &o[], double &h[], double &l[], double &c[])
{
   ArrayResize(o, count);
   ArrayResize(h, count);
   ArrayResize(l, count);
   ArrayResize(c, count);
   if(CopyOpen(_Symbol, tf, start, count, o) != count) return false;
   if(CopyHigh(_Symbol, tf, start, count, h) != count) return false;
   if(CopyLow (_Symbol, tf, start, count, l) != count) return false;
   if(CopyClose(_Symbol, tf, start, count, c) != count) return false;
   return true;
}
bool IsSwingLow(const double &l[], int i, int leftRight)
{
   for(int k=1;k<=leftRight;k++)
      if(l[i] >= l[i-k] || l[i] >= l[i+k]) return false;
   return true;
}
bool IsSwingHigh(const double &h[], int i, int leftRight)
{
   for(int k=1;k<=leftRight;k++)
      if(h[i] <= h[i-k] || h[i] <= h[i+k]) return false;
   return true;
}

// EMA helpers
bool GetEMA(const int handle, const int shift, double &val)
{
   double b[1];
   if(handle == INVALID_HANDLE) return false;
   if(CopyBuffer(handle, 0, shift, 1, b) != 1) return false;
   val = b[0];
   return true;
}
bool GetCloseTF(ENUM_TIMEFRAMES tf, int shift, double &closeVal)
{
   double c[1];
   if(CopyClose(_Symbol, tf, shift, 1, c) != 1) return false;
   closeVal = c[0];
   return true;
}
enum ENUM_TREND_DIR { TREND_UNKNOWN=0, TREND_UP=1, TREND_DOWN=-1 };
ENUM_TREND_DIR TrendByEMA(ENUM_TIMEFRAMES tf, int h21, int h50)
{
   double e21=0,e50=0, cl=0;
   if(!GetEMA(h21, 1, e21) || !GetEMA(h50, 1, e50) || !GetCloseTF(tf, 1, cl))
      return TREND_UNKNOWN;

   if(e21 > e50 && cl >= e21) return TREND_UP;
   if(e21 < e50 && cl <= e21) return TREND_DOWN;
   return TREND_UNKNOWN;
}
string TrendToString(ENUM_TREND_DIR d)
{
   if(d==TREND_UP) return "UP";
   if(d==TREND_DOWN) return "DOWN";
   return "MIXED";
}

bool ReadRecentCloses(const ENUM_TIMEFRAMES tf, const int startShift, const int count, double &arr[])
{
   ArrayResize(arr, count);
   return (CopyClose(_Symbol, tf, startShift, count, arr) == count);
}

bool ReadRecentOpens(const ENUM_TIMEFRAMES tf, const int startShift, const int count, double &arr[])
{
   ArrayResize(arr, count);
   return (CopyOpen(_Symbol, tf, startShift, count, arr) == count);
}

bool GetATRValueTF(const ENUM_TIMEFRAMES tf, const int shift, const int period, double &atrVal)
{
   atrVal = 0.0;
   int h = iATR(_Symbol, tf, MathMax(period, 2));
   if(h == INVALID_HANDLE) return false;

   double b[1];
   bool ok = (CopyBuffer(h, 0, shift, 1, b) == 1);
   IndicatorRelease(h);
   if(!ok) return false;

   atrVal = b[0];
   return (atrVal > 0.0);
}

bool GetEMATFValue(const ENUM_TIMEFRAMES tf, const int period, const int shift, double &val)
{
   val = 0.0;
   int h = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return false;

   double b[1];
   bool ok = (CopyBuffer(h, 0, shift, 1, b) == 1);
   IndicatorRelease(h);
   if(!ok) return false;

   val = b[0];
   return true;
}


bool GetBarOHLCV(const ENUM_TIMEFRAMES tf,
                 const int shift,
                 double &o, double &h, double &l, double &c, long &v)
{
   o = iOpen(_Symbol, tf, shift);
   h = iHigh(_Symbol, tf, shift);
   l = iLow(_Symbol, tf, shift);
   c = iClose(_Symbol, tf, shift);
   v = (long)iVolume(_Symbol, tf, shift);
   return (o > 0.0 && h > 0.0 && l > 0.0 && c > 0.0 && h >= l);
}

bool TickVolumeBreakoutFilter(const ENUM_ORDER_TYPE orderType,
                              const ENUM_TIMEFRAMES tf,
                              const double atr0,
                              string &why)
{
   why = "";

   if(!InpUseTickVolumeBreakoutFilter)
      return true;

   int shift = SignalBarShift();
   double o0=0,h0=0,l0=0,c0=0, ph=0, pl=0;
   long v0=0;
   if(!GetBarOHLCV(tf, shift, o0, h0, l0, c0, v0))
   {
      why = "TickVolumeDataUnavailable";
      return false;
   }

   ph = iHigh(_Symbol, tf, shift + 1);
   pl = iLow (_Symbol, tf, shift + 1);
   if(ph <= 0.0 || pl <= 0.0)
   {
      why = "TickVolumePrevBarUnavailable";
      return false;
   }

   int lookback = MathMax(InpTickVolumeLookback, 3);
   double sum = 0.0;
   int counted = 0;
   for(int i = shift + 1; i <= shift + lookback; ++i)
   {
      long vi = (long)iVolume(_Symbol, tf, i);
      if(vi > 0)
      {
         sum += (double)vi;
         counted++;
      }
   }
   if(counted <= 0)
   {
      why = "TickVolumeAverageUnavailable";
      return false;
   }

   double avgVol = sum / (double)counted;
   double atrUse = atr0;
   if(atrUse <= 0.0)
      GetATRValueTF(tf, 1, InpATRPeriod, atrUse);

   double breakoutPad = MathMax(InpBreakoutBufferPrice, (atrUse > 0.0 ? atrUse * 0.05 : 0.0));
   bool breakout = (orderType == ORDER_TYPE_BUY) ? (c0 > (ph + breakoutPad))
                                                 : (c0 < (pl - breakoutPad));

   if(!breakout)
      return true;

   double needVol = avgVol * AdaptiveTickVolumeNeedMult(atrUse);
   if((double)v0 + 1e-9 < needVol)
   {
      why = StringFormat("TickVolumeWeak(vol=%ld avg=%.1f need>=%.1f)", v0, avgVol, needVol);
      return false;
   }

   return true;
}

bool ThreeLayerMTFFilter(const ENUM_ORDER_TYPE orderType,
                         const ENUM_TIMEFRAMES entryTF,
                         const double atr0,
                         string &why)
{
   why = "";

   if(!InpUseThreeLayerMTF)
      return true;

   ENUM_TIMEFRAMES htf = InpMTF_HigherTF;
   ENUM_TIMEFRAMES mtf = InpMTF_MidTF;
   bool buy = (orderType == ORDER_TYPE_BUY);

   double hE21_1=0,hE21_3=0,hE50_1=0,hC1=0;
   double mE21_1=0,mE50_1=0,mC1=0;
   double eE21_1=0,eE21_2=0,eC1=0,eH2=0,eL2=0;

   if(!GetEMATFValue(htf, InpEMA21, 1, hE21_1) || !GetEMATFValue(htf, InpEMA21, 3, hE21_3) ||
      !GetEMATFValue(htf, InpEMA50, 1, hE50_1) || !GetCloseTF(htf, 1, hC1) ||
      !GetEMATFValue(mtf, InpEMA21, 1, mE21_1) || !GetEMATFValue(mtf, InpEMA50, 1, mE50_1) ||
      !GetCloseTF(mtf, 1, mC1) ||
      !GetEMATFValue(entryTF, InpEMA21, 1, eE21_1) || !GetEMATFValue(entryTF, InpEMA21, 2, eE21_2) ||
      !GetCloseTF(entryTF, 1, eC1))
   {
      why = "ThreeLayerMTFDataUnavailable";
      return false;
   }

   eH2 = iHigh(_Symbol, entryTF, 2);
   eL2 = iLow (_Symbol, entryTF, 2);

   double atrUse = atr0;
   if(atrUse <= 0.0)
      GetATRValueTF(entryTF, 1, InpATRPeriod, atrUse);

   double pullbackBand = AdaptiveThreeLayerPullbackBand(atrUse, MathAbs(mE21_1 - mE50_1));
   double trendSlopeH1 = hE21_1 - hE21_3;

   bool htfTrend = buy ? (hE21_1 > hE50_1 && hC1 >= hE21_1 && trendSlopeH1 >= InpTrendSlopeMinPrice)
                       : (hE21_1 < hE50_1 && hC1 <= hE21_1 && trendSlopeH1 <= -InpTrendSlopeMinPrice);
   if(!htfTrend)
   {
      why = "ThreeLayerHTFTrendFail";
      return false;
   }

   bool midAlign = buy ? (mE21_1 > mE50_1 && mC1 >= (mE50_1 - pullbackBand))
                       : (mE21_1 < mE50_1 && mC1 <= (mE50_1 + pullbackBand));
   if(!midAlign)
   {
      why = "ThreeLayerMidAlignFail";
      return false;
   }

   bool touchedPullback = false;
   int lookback = MathMax(InpMTF_PullbackLookbackBars, 2);
   for(int i=1; i<=lookback; ++i)
   {
      double mClose=0,m21=0,m50=0;
      if(!GetCloseTF(mtf, i, mClose) || !GetEMATFValue(mtf, InpEMA21, i, m21) || !GetEMATFValue(mtf, InpEMA50, i, m50))
         continue;

      if(buy)
      {
         if(mClose <= (m21 + pullbackBand) && mClose >= (m50 - pullbackBand))
         {
            touchedPullback = true;
            break;
         }
      }
      else
      {
         if(mClose >= (m21 - pullbackBand) && mClose <= (m50 + pullbackBand))
         {
            touchedPullback = true;
            break;
         }
      }
   }
   if(!touchedPullback)
   {
      why = "ThreeLayerNoRecentPullback";
      return false;
   }

   double entryBand = (atrUse > 0.0 ? atrUse * 0.08 : MathAbs(eE21_1 - eE21_2) * 0.50);
   bool entryConfirm = buy ? (eC1 > eE21_1 && eE21_1 >= eE21_2 && (eC1 > eH2 || eC1 >= (eE21_1 + entryBand)))
                           : (eC1 < eE21_1 && eE21_1 <= eE21_2 && (eC1 < eL2 || eC1 <= (eE21_1 - entryBand)));
   if(!entryConfirm)
   {
      why = "ThreeLayerEntryConfirmFail";
      return false;
   }

   return true;
}

double Clamp01Range(const double v, const double lo, const double hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

double VolatilityRatioByATR(const double atrUse)
{
   if(atrUse <= 0.0 || InpATRHighThreshold <= 0.0)
      return 1.0;
   return atrUse / InpATRHighThreshold;
}

double AdaptiveTrendSlopeNeed(const double atrUse)
{
   double ratio = VolatilityRatioByATR(atrUse);
   double base  = MathMax(InpTrendSlopeMinPrice, 0.01);
   if(ratio <= 0.70) return MathMax(base * 0.72, 0.03);
   if(ratio >= 1.20) return base * 0.92;
   return base * SessionThresholdFactor();
}

double AdaptiveTrendSeparationNeed(const double atrUse)
{
   double ratio = VolatilityRatioByATR(atrUse);
   double base  = MathMax(InpTrendSeparationMinPrice, 0.01);
   if(ratio <= 0.70) return MathMax(base * 0.78, 0.05);
   if(ratio >= 1.20) return base * 0.95;
   return base * SessionThresholdFactor();
}

double AdaptiveEMA21DistanceMult(const double atrUse)
{
   double ratio = VolatilityRatioByATR(atrUse);
   double base  = MathMax(InpMaxPriceToEMA21_ATR_Mult, 0.10);
   if(ratio <= 0.70) return base * 1.30;
   if(ratio >= 1.20) return base * 1.20;
   return base * 1.10;
}

double AdaptiveAntiChaseMult(const double atrUse)
{
   double ratio = VolatilityRatioByATR(atrUse);
   double base  = MathMax(InpAntiChaseDistanceATR_Mult, 0.10);
   if(ratio <= 0.70) return base * 1.25;
   if(ratio >= 1.20) return base * 1.15;
   return base * 1.08;
}

double AdaptiveExhaustionMult(const double atrUse)
{
   double ratio = VolatilityRatioByATR(atrUse);
   double base  = MathMax(InpExhaustionBodyATR_Mult, 0.10);
   if(ratio <= 0.70) return base * 1.20;
   if(ratio >= 1.20) return base * 1.10;
   return base * SessionThresholdFactor();
}

double AdaptiveTickVolumeNeedMult(const double atrUse)
{
   double ratio = VolatilityRatioByATR(atrUse);
   double base  = MathMax(InpTickVolumeMultiplier, 0.10);
   if(ratio <= 0.70) return MathMax(base * 0.92, 1.00);
   if(ratio >= 1.20) return MathMax(base * 0.97, 1.00);
   return MathMax(base * SessionThresholdFactor(), 1.00);
}

double AdaptiveThreeLayerPullbackBand(const double atrUse, const double fallbackGap)
{
   if(atrUse <= 0.0)
      return MathMax(fallbackGap * 0.55, 0.0);

   double ratio = VolatilityRatioByATR(atrUse);
   double mul = 0.35;
   if(ratio <= 0.70) mul = 0.48;
   else if(ratio >= 1.20) mul = 0.42;
   return atrUse * mul;
}

bool FindSwingRange(const ENUM_TIMEFRAMES tf, const int lookbackBars, double &swingHigh, double &swingLow)
{
   swingHigh = -DBL_MAX; swingLow = DBL_MAX;
   int lb = MathMax(lookbackBars, 10);
   for(int i=1; i<=lb; ++i)
   {
      double h = iHigh(_Symbol, tf, i);
      double l = iLow(_Symbol, tf, i);
      if(h <= 0.0 || l <= 0.0) continue;
      if(h > swingHigh) swingHigh = h;
      if(l < swingLow)  swingLow  = l;
   }
   return (swingHigh > swingLow && swingHigh < DBL_MAX && swingLow > -DBL_MAX);
}
double ApplyVolatilityAdjustedRR(const double baseRR, const double atr0)
{
   if(!InpEnableVolatilityTPAdjust) return baseRR;
   double ratio = VolatilityRatioByATR(atr0);
   double extra = MathMax(0.0, ratio - 1.0) * MathMax(InpVolatilityTPFactor, 0.0);
   double mult  = MathMin(MathMax(1.0 + extra, 0.80), MathMax(InpVolatilityTPCapMult, 1.0));
   return MathMax(baseRR * mult, 0.20);
}
double BlendTPWithFib(const ENUM_ORDER_TYPE orderType, const ENUM_TIMEFRAMES tf, const double entryPrice, const double currentTP)
{
   if(!InpEnableFibTPGuide) return currentTP;
   double hi=0.0, lo=0.0;
   if(!FindSwingRange(tf, InpFibSwingLookbackBars, hi, lo)) return currentTP;
   double range = hi - lo;
   if(range <= 0.0) return currentTP;
   double fibTP = currentTP;
   if(orderType == ORDER_TYPE_BUY)
      fibTP = MathMax(currentTP, entryPrice + range * 0.618);
   else
      fibTP = MathMin(currentTP, entryPrice - range * 0.618);
   double blend = Clamp01Range(InpFibTPBlend, 0.0, 1.0);
   double out = currentTP + (fibTP - currentTP) * blend;
   return NormalizeToTick(out);
}
void ApplyPartialCloseLogic()
{
   if(!InpEnablePartialClose) return;
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minVol <= 0.0) minVol = 0.01;
   if(step <= 0.0) step = minVol;

   for(int i = PositionsTotal()-1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PartialMarkHas(ticket)) continue;

      long type = (long)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(openPrice <= 0.0 || sl <= 0.0 || vol <= 0.0) continue;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double current = (type == POSITION_TYPE_BUY ? bid : ask);
      double riskDist = MathAbs(openPrice - sl);
      double profitDist = (type == POSITION_TYPE_BUY ? current - openPrice : openPrice - current);
      if(riskDist <= 0.0 || profitDist <= 0.0) continue;

      double rrNow = profitDist / riskDist;
      if(rrNow + 1e-9 < MathMax(InpPartialClose_RR, 0.1)) continue;

      double closeVol = NormalizeVolume(vol * Clamp01Range(InpPartialClose_Fraction, 0.05, 0.95));
      double remain = vol - closeVol;
      if(closeVol < minVol) continue;
      if(remain < MathMax(minVol, InpPartialClose_MinLot))
      {
         closeVol = NormalizeVolume(vol - MathMax(minVol, InpPartialClose_MinLot));
         remain = vol - closeVol;
      }
      if(closeVol < minVol || remain < minVol) continue;

      ResetLastError();
      if(trade.PositionClosePartial(ticket, closeVol))
      {
         PartialMarkSet(ticket);
         Log(StringFormat("PartialClose: ticket=%I64u rr=%.2f closeVol=%.2f remain=%.2f", ticket, rrNow, closeVol, remain));
      }
   }
}

bool EnhancedTrendDirectionFilter(const ENUM_ORDER_TYPE orderType,
                                  const ENUM_TIMEFRAMES tf,
                                  const double atr0,
                                  string &why)
{
   why = "";

   if(!InpUseEnhancedTrendDirection)
      return true;

   double e21_1=0.0, e21_3=0.0, e50_1=0.0, cl1=0.0;
   if(!GetEMA(hEMA21_TF, 1, e21_1) || !GetEMA(hEMA21_TF, 3, e21_3) ||
      !GetEMA(hEMA50_TF, 1, e50_1) || !GetCloseTF(tf, 1, cl1))
   {
      why = "EnhancedTrendDataUnavailable";
      return false;
   }

   double slope21 = e21_1 - e21_3;
   double sep     = MathAbs(e21_1 - e50_1);
   double atrUse  = (atr0 > 0.0 ? atr0 : MathAbs(e21_1 - e50_1) * 2.0);
   double distToEMA21 = MathAbs(cl1 - e21_1);

   double slopeNeed = AdaptiveTrendSlopeNeed(atrUse);
   double sepNeed   = AdaptiveTrendSeparationNeed(atrUse);
   double maxDist   = atrUse * AdaptiveEMA21DistanceMult(atrUse);

   bool buy = (orderType == ORDER_TYPE_BUY);
   bool dirOk = buy ? (e21_1 > e50_1 && slope21 >= slopeNeed)
                    : (e21_1 < e50_1 && slope21 <= -slopeNeed);

   if(!dirOk)
   {
      why = StringFormat("EnhancedTrendDirFail(close=%.2f ema21=%.2f ema50=%.2f slope21=%.2f needSlope>=%.2f)",
                         cl1, e21_1, e50_1, slope21, slopeNeed);
      return false;
   }

   if(sep < sepNeed)
   {
      why = StringFormat("EnhancedTrendSepWeak(sep=%.2f need>=%.2f)", sep, sepNeed);
      return false;
   }

   if(maxDist > 0.0 && distToEMA21 > maxDist)
   {
      why = StringFormat("EnhancedTrendTooFarFromEMA21(dist=%.2f max=%.2f)", distToEMA21, maxDist);
      return false;
   }

   return true;
}

bool AntiExhaustionAntiChaseFilter(const ENUM_ORDER_TYPE orderType,
                                   const ENUM_TIMEFRAMES tf,
                                   const double atr0,
                                   string &why)
{
   why = "";

   int barsNeed = MathMax(InpAntiExhaustionBars, 2);
   double o[], c[];
   if(!ReadRecentOpens(tf, 1, barsNeed, o) || !ReadRecentCloses(tf, 1, barsNeed, c))
   {
      why = "AntiExhaustionDataUnavailable";
      return false;
   }

   double sameDirBodySum = 0.0;
   int sameDirCount = 0;
   for(int i=0; i<barsNeed; ++i)
   {
      double body = MathAbs(c[i] - o[i]);
      bool bull = (c[i] > o[i]);
      bool bear = (c[i] < o[i]);
      if(orderType == ORDER_TYPE_BUY && bull)
      {
         sameDirBodySum += body;
         sameDirCount++;
      }
      else if(orderType == ORDER_TYPE_SELL && bear)
      {
         sameDirBodySum += body;
         sameDirCount++;
      }
   }

   double atrUse = atr0;
   if(atrUse <= 0.0)
      GetATRValueTF(tf, 1, InpATRPeriod, atrUse);

   if(InpUseAntiExhaustionFilter && atrUse > 0.0 && sameDirCount >= barsNeed)
   {
      double exhaustionNeed = atrUse * AdaptiveExhaustionMult(atrUse);
      if(sameDirBodySum >= exhaustionNeed)
      {
         why = StringFormat("ExhaustionDetected(sumBody=%.2f atr=%.2f bars=%d)",
                            sameDirBodySum, atrUse, sameDirCount);
         return false;
      }
   }

   if(InpUseAntiChaseFilter)
   {
      double e21=0.0, cl1=0.0;
      if(GetEMA(hEMA21_TF, 1, e21) && GetCloseTF(tf, 1, cl1) && atrUse > 0.0)
      {
         double chaseDist = MathAbs(cl1 - e21);
         double chaseMax  = atrUse * AdaptiveAntiChaseMult(atrUse);
         if(chaseDist > chaseMax)
         {
            why = StringFormat("AntiChaseTooFar(dist=%.2f max=%.2f)", chaseDist, chaseMax);
            return false;
         }
      }
   }

   return true;
}

bool BuildHybridSL(const ENUM_ORDER_TYPE orderType,
                   const ENUM_TIMEFRAMES tf,
                   const double entryPrice,
                   const double atr0,
                   double &outSL,
                   double &outBufferPrice,
                   string &why)
{
   why = "";
   outSL = 0.0;
   outBufferPrice = 0.0;

   double signalSL = 0.0;
   string sigWhy = "";
   if(!BuildSignalCandleSL(orderType, tf, entryPrice, signalSL, outBufferPrice, sigWhy))
   {
      why = sigWhy;
      return false;
   }

   if(!InpUseHybridSignalATR_SL)
   {
      outSL = signalSL;
      return true;
   }

   double srH=0.0, srL=0.0;
   FindRecentSRLevels(tf, srH, srL);

   double atrUse = atr0;
   if(atrUse <= 0.0)
      GetATRValueTF(tf, 1, InpATRPeriod, atrUse);

   double structSL = signalSL;
   double atrBuffer = MathMax((atrUse > 0.0 ? atrUse * MathMax(InpHybridSL_ATR_Mult, 0.1) : 0.0), outBufferPrice);

   if(orderType == ORDER_TYPE_BUY)
   {
      double candidate = signalSL;
      if(srL > 0.0)
         candidate = NormalizeToTick(srL - atrBuffer);
      if(candidate < entryPrice)
         structSL = candidate;

      outSL = MathMin(signalSL, structSL);
   }
   else
   {
      double candidate = signalSL;
      if(srH > 0.0)
         candidate = NormalizeToTick(srH + atrBuffer);
      if(candidate > entryPrice)
         structSL = candidate;

      outSL = MathMax(signalSL, structSL);
   }

   double minSLDist = ComputeMinSLDistancePrice(tf, atrUse);
   if(minSLDist > 0.0)
   {
      if(orderType == ORDER_TYPE_BUY)
      {
         if((entryPrice - outSL) < minSLDist)
            outSL = NormalizeToTick(entryPrice - minSLDist);
      }
      else
      {
         if((outSL - entryPrice) < minSLDist)
            outSL = NormalizeToTick(entryPrice + minSLDist);
      }
   }

   if((orderType == ORDER_TYPE_BUY  && outSL >= entryPrice) ||
      (orderType == ORDER_TYPE_SELL && outSL <= entryPrice))
   {
      why = "HybridSLWrongSide";
      return false;
   }

   if(!EnsureSLMeetsBrokerStopLevel(orderType, entryPrice, outSL))
   {
      why = "HybridSLStopLevelFail";
      return false;
   }

   return true;
}

string F2(const double v)
{
   return DoubleToString(v, 2);
}

string BuildTechnicalFailReason(const ENUM_ORDER_TYPE orderType,
                                const string modeTag,
                                const double rsiA,
                                const double adx0,
                                const double atr0,
                                const bool bandsOk,
                                const double bbUp,
                                const double bbMid,
                                const double bbLow,
                                const ENUM_TREND_DIR t1,
                                const ENUM_TREND_DIR t2,
                                const double ema21_tf,
                                const double ema50_tf,
                                const double stK,
                                const double stD,
                                const string rawReasons)
{
   string out = "";
   bool buy = (orderType == ORDER_TYPE_BUY);
   bool tfFollow = IsTrendFollowContext(modeTag);

   double close1 = 0.0;
   GetCloseTF(CalcTF(), 1, close1);

   bool crossUp = false, crossDown = false;
   if(hStoch != INVALID_HANDLE)
   {
      double k0=0.0,k1=0.0,k2=0.0,d0=0.0,d1=0.0,d2=0.0;
      if(ReadStoch(k0,k1,k2,d0,d1,d2))
      {
         crossUp   = (k2 <= d2 && k1 > d1);
         crossDown = (k2 >= d2 && k1 < d1);
      }
   }

   if(StringFind(rawReasons, "MTFTrendNoAlign;") >= 0)
   {
      string need = (buy ? "BUY cần H1 hoặc M15 = UP" : "SELL cần H1 hoặc M15 = DOWN");
      string cur  = StringFormat("hiện tại H1=%s, M15=%s", TrendToString(t1), TrendToString(t2));
      if(out != "") out += " | ";
      out += "MTFTrendNoAlign (" + StringFormat("%s",need) + "; " + StringFormat("%s",cur) + ")";
   }

   if(StringFind(rawReasons, "EMAGateFail;") >= 0)
   {
      string need = (buy ? "BUY cần Close>=EMA21 hoặc xu hướng H1 = UP"
                         : "SELL cần Close<=EMA21 hoặc xu hướng H1 = DOWN");
      string cur  = StringFormat("hiện tại Close=%s, EMA21=%s, EMA50=%s, TrendH1=%s",
                                 F2(close1), F2(ema21_tf), F2(ema50_tf), TrendToString(t1));
      if(out != "") out += " | ";
      out += "EMAGateFail (" + StringFormat("%s",need) + "; " + StringFormat("%s",cur) + ")";
   }

   if(StringFind(rawReasons, "StochFail;") >= 0)
   {
      string need = "";
      if(tfFollow)
      {
         if(buy)
            need = StringFormat("BUY cần K>D và K>=%s hoặc crossUp với K>=%s",
                                F2(EffectiveTFStochBuyMinK()), F2(EffectiveTFStochBuyCrossMinK()));
         else
            need = StringFormat("SELL cần K<D và K<=%s hoặc crossDown với K<=%s",
                                F2(EffectiveTFStochSellMaxK()), F2(EffectiveTFStochSellCrossMaxK()));
      }
      else
      {
         if(buy)
            need = StringFormat("BUY cần K<=%s hoặc K cắt lên D",
                                F2(InpStochOversold));
         else
            need = StringFormat("SELL cần K>=%s hoặc K cắt xuống D",
                                F2(InpStochOverbought));
      }

      string cur = StringFormat("hiện tại K=%s, D=%s", F2(stK), F2(stD));
      if(tfFollow)
      {
         if(buy)  cur += StringFormat(", crossUp=%s", (crossUp?"true":"false"));
         else     cur += StringFormat(", crossDown=%s", (crossDown?"true":"false"));
      }

      if(out != "") out += " | ";
      out += "StochFail (" + StringFormat("%s",need) + "; " + StringFormat("%s",cur) + ")";
   }

   if(StringFind(rawReasons, "RSIFail;") >= 0)
   {
      string need = "";
      if(!tfFollow)
      {
         if(buy)
            need = StringFormat("BUY yêu cầu RSI<=%s hoặc <=%s",
                                F2(InpRSI_OS), F2(gRSIOversold));
         else
            need = StringFormat("SELL yêu cầu RSI>=%s hoặc >=%s",
                                F2(InpRSI_OB), F2(gRSIOverbought));
      }
      else
      {
         need = "RSI phải nằm trong vùng hợp lệ theo bộ lọc kỹ thuật";
      }

      string cur = StringFormat("hiện tại RSI=%s", F2(rsiA));

      if(out != "") out += " | ";
      out += "RSIFail (" + StringFormat("%s",need) + "; " + StringFormat("%s",cur) + ")";
   }

   if(StringFind(rawReasons, "PAFail;") >= 0)
   {
      string need = (buy ? "BUY cần nến xác nhận tăng hợp lệ" : "SELL cần nến xác nhận giảm hợp lệ");
      if(out != "") out += " | ";
      out += "PAFail (" + StringFormat("%s",need) + ")";
   }

   if(StringFind(rawReasons, "SRFail;") >= 0)
   {
      string need = (buy
                     ? StringFormat("BUY cần giá gần hỗ trợ trong buffer <= %s", F2(InpSRBufferPrice))
                     : StringFormat("SELL cần giá gần kháng cự trong buffer <= %s", F2(InpSRBufferPrice)));
      if(out != "") out += " | ";
      out += "SRFail (" + StringFormat("%s",need) + ")";
   }

   if(StringFind(rawReasons, "SRSoft;") >= 0)
   {
      string need = "Xác nhận S/R chưa đủ mạnh, EA chuyển sang chế độ siết rủi ro";
      if(out != "") out += " | ";
      out += "SRSoft (" + StringFormat("%s",need) + ")";
   }

   if(StringFind(rawReasons, "TrendDirectionUpgradeFail;") >= 0)
   {
      if(out != "") out += " | ";
      out += "TrendDirectionUpgradeFail (hướng xu hướng chưa đủ rõ theo slope/separation/distance filter)";
   }

   if(StringFind(rawReasons, "AntiChaseExhaustionFail;") >= 0)
   {
      if(out != "") out += " | ";
      out += "AntiChaseExhaustionFail (giá đang bị kéo quá xa EMA21 hoặc đang ở cuối sóng)";
   }

   if(StringFind(rawReasons, "GateUnknownFail;") >= 0 || rawReasons == "")
   {
      string fallback = "";

      if(InpRequireMTFTrendAlign)
      {
         bool mtfOk = (buy ? (t1==TREND_UP || t2==TREND_UP)
                           : (t1==TREND_DOWN || t2==TREND_DOWN));
         if(!mtfOk)
         {
            if(fallback != "") fallback += " | ";
            fallback += StringFormat("MTFTrendNoAlign (%s; hiện tại H1=%s, M15=%s)",
                                     (buy ? "BUY cần H1 hoặc M15 = UP" : "SELL cần H1 hoặc M15 = DOWN"),
                                     TrendToString(t1), TrendToString(t2));
         }
      }

      if(InpUseEMA21_50Filter)
      {
         bool emaOk2 = true;
         if(buy)
            emaOk2 = (close1 >= ema21_tf) || (t1 == TREND_UP);
         else
            emaOk2 = (close1 <= ema21_tf) || (t1 == TREND_DOWN);

         if(!emaOk2)
         {
            if(fallback != "") fallback += " | ";
            fallback += StringFormat("EMAGateFail (%s; hiện tại Close=%s, EMA21=%s, TrendH1=%s)",
                                     (buy ? "BUY cần Close>=EMA21 hoặc xu hướng H1 = UP"
                                          : "SELL cần Close<=EMA21 hoặc xu hướng H1 = DOWN"),
                                     F2(close1), F2(ema21_tf), TrendToString(t1));
         }
      }

      if(InpUseStochFilter)
      {
         bool stochFailNow = false;
         string need = "";
         string cur  = StringFormat("hiện tại K=%s, D=%s", F2(stK), F2(stD));

         if(tfFollow)
         {
            if(buy)
            {
               bool cond = ((stK > stD) && (stK >= InpTF_StochBuy_MinK)) || (crossUp && stK >= InpTF_StochBuy_CrossMinK);
               if(!cond)
               {
                  stochFailNow = true;
                  need = StringFormat("BUY cần K>D và K>=%s hoặc crossUp với K>=%s",
                                      F2(EffectiveTFStochBuyMinK()), F2(EffectiveTFStochBuyCrossMinK()));
                  cur += StringFormat(", crossUp=%s", (crossUp?"true":"false"));
               }
            }
            else
            {
               bool cond = ((stK < stD) && (stK <= InpTF_StochSell_MaxK)) || (crossDown && stK <= InpTF_StochSell_CrossMaxK);
               if(!cond)
               {
                  stochFailNow = true;
                  need = StringFormat("SELL cần K<D và K<=%s hoặc crossDown với K<=%s",
                                      F2(EffectiveTFStochSellMaxK()), F2(EffectiveTFStochSellCrossMaxK()));
                  cur += StringFormat(", crossDown=%s", (crossDown?"true":"false"));
               }
            }
         }
         else
         {
            if(buy)
            {
               bool cond = (stK <= InpStochOversold) || crossUp;
               if(!cond)
               {
                  stochFailNow = true;
                  need = StringFormat("BUY cần K<=%s hoặc K cắt lên D", F2(InpStochOversold));
                  cur += StringFormat(", crossUp=%s", (crossUp?"true":"false"));
               }
            }
            else
            {
               bool cond = (stK >= InpStochOverbought) || crossDown;
               if(!cond)
               {
                  stochFailNow = true;
                  need = StringFormat("SELL cần K>=%s hoặc K cắt xuống D", F2(InpStochOverbought));
                  cur += StringFormat(", crossDown=%s", (crossDown?"true":"false"));
               }
            }
         }

         if(stochFailNow)
         {
            if(fallback != "") fallback += " | ";
            fallback += "StochFail (" + StringFormat("%s",need) + "; " + StringFormat("%s",cur) + ")";
         }
      }

      if(InpUseRSI_OBOS_Filter && !tfFollow)
      {
         bool rsiBad = false;
         string need = "";

         if(buy && !((rsiA <= InpRSI_OS) || (rsiA <= gRSIOversold)))
         {
            rsiBad = true;
            need = StringFormat("BUY yêu cầu RSI<=%s hoặc <=%s", F2(InpRSI_OS), F2(gRSIOversold));
         }
         else if(!buy && !((rsiA >= InpRSI_OB) || (rsiA >= gRSIOverbought)))
         {
            rsiBad = true;
            need = StringFormat("SELL yêu cầu RSI>=%s hoặc >=%s", F2(InpRSI_OB), F2(gRSIOverbought));
         }

         if(rsiBad)
         {
            if(fallback != "") fallback += " | ";
            fallback += "RSIFail (" + StringFormat("%s",need) + "; hiện tại RSI=" + F2(rsiA) + ")";
         }
      }

      if(InpUsePriceActionConfirm)
      {
         string paTag = "NONE";
         bool paOk2 = PriceActionConfirm(orderType, CalcTF(), paTag);
         if(!paOk2)
         {
            if(fallback != "") fallback += " | ";
            fallback += StringFormat("PAFail (%s; PA hiện tại=%s)",
                                     (buy ? "BUY cần nến xác nhận tăng hợp lệ" : "SELL cần nến xác nhận giảm hợp lệ"),
                                     paTag);
         }
      }

      if(fallback != "")
         return fallback;
   }

      if(out == "")
   {
      string rsiCond = (rsiA >= 50 ? "OK" : "FAIL");
      string adxCond = (adx0 >= 15 ? "OK" : "FAIL");
      string bbCond  = (bandsOk ? "OK" : "FAIL");
   
      out = StringFormat(
         "RSI(%s>=50:%s) | ADX(%s>=15:%s) | ATR(%s volatility check) | BB(%s)",
         F2(rsiA), rsiCond,
         F2(adx0), adxCond,
         F2(atr0),
         bbCond
      );
   }
   return out;
}

string BuildNoSignalReason(const string modeTag,
                           const double rsiA,
                           const double rsiB,
                           const double adx0,
                           const double atr0,
                           const bool adxOk,
                           const bool bandsOk,
                           const double up0,
                           const double mid0,
                           const double low0,
                           const double fastA,
                           const double fastB,
                           const double slowA,
                           const double slowB,
                           const bool upBias,
                           const bool downBias,
                           const bool biasStrong,
                           const double biasDist,
                           const bool isVolatile,
                           const bool isSideways,
                           const bool envTightNow,
                           const bool buyTrend,
                           const bool sellTrend,
                           const bool buyRange,
                           const bool sellRange,
                           const bool buyVol,
                           const bool sellVol)
{
   string out = "";
   bool crossUp   = (fastB <= slowB && fastA > slowA);
   bool crossDown = (fastB >= slowB && fastA < slowA);
   bool recentCrossUp   = crossUp;
   bool recentCrossDown = crossDown;
   if(EffectivePullbackRecentCrossBars() >= 2)
   {
      if((fastB <= slowB && fastA > slowA) || (fastA > slowA && fastB > slowB)) recentCrossUp = true;
      if((fastB >= slowB && fastA < slowA) || (fastA < slowA && fastB < slowB)) recentCrossDown = true;
   }

   if(modeTag == "TREND")
   {
      if(gTrendMode == TREND_PULLBACK)
      {
         if(!crossUp && !crossDown)
         {
            out += StringFormat("Không có giao cắt EMA gần đây hợp lệ cho PULLBACK (recentCrossUp=%s, recentCrossDown=%s)",
                                (recentCrossUp?"true":"false"), (recentCrossDown?"true":"false"));
         }
         if(!upBias && !downBias)
         {
            if(out != "") out += " | ";
            out += StringFormat("Bias EMA chưa rõ (Fast=%s, Slow=%s, |bias|=%s, yêu cầu >=%s)",
                                F2(fastA), F2(slowA), F2(biasDist), F2(gBiasMinDistancePrice));
         }
         if(rsiA > gRSIOversold && rsiA < gRSIOverbought)
         {
            if(out != "") out += " | ";
            out += StringFormat("RSI chưa vào vùng pullback M5 (BUY cần <=%s, SELL cần >=%s; hiện tại RSI=%s)",
                                F2(gRSIOversold), F2(gRSIOverbought), F2(rsiA));
         }
         if(envTightNow && InpTightPullback_MinADX > 0.0 && (!adxOk || adx0 < InpTightPullback_MinADX))
         {
            if(out != "") out += " | ";
            out += StringFormat("Môi trường siết chặt yêu cầu ADX>=%s; hiện tại ADX=%s",
                                F2(InpTightPullback_MinADX), F2(adx0));
         }
      }
      else
      {
         if(!upBias && !downBias)
         {
            out += StringFormat("Bias xu hướng chưa rõ (Fast=%s, Slow=%s, |bias|=%s, yêu cầu >=%s)",
                                F2(fastA), F2(slowA), F2(biasDist), F2(gBiasMinDistancePrice));
         }
         if(!buyTrend && !sellTrend)
         {
            if(out != "") out += " | ";
            out += StringFormat("TREND_FOLLOW chưa đạt: BUY cần RSI>=50, SELL cần RSI<=50; hiện tại RSI=%s", F2(rsiA));
         }
         if(envTightNow)
         {
            if(rsiA < InpTrendTight_RSI_BuyMin && rsiA > InpTrendTight_RSI_SellMax)
            {
               if(out != "") out += " | ";
               out += StringFormat("Môi trường siết chặt yêu cầu BUY RSI>=%s hoặc SELL RSI<=%s; hiện tại RSI=%s",
                                   F2(InpTrendTight_RSI_BuyMin), F2(InpTrendTight_RSI_SellMax), F2(rsiA));
            }
         }

         if(InpUseEnhancedTrendDirection)
         {
            string trendWhy="";
            if(!EnhancedTrendDirectionFilter(ORDER_TYPE_BUY, CalcTF(), atr0, trendWhy) &&
               !EnhancedTrendDirectionFilter(ORDER_TYPE_SELL, CalcTF(), atr0, trendWhy))
            {
               if(out != "") out += " | ";
               out += "TrendDirectionUpgrade chưa đạt";
            }
         }
      }
   }
   else if(modeTag == "RANGE")
   {
      if(!bandsOk)
      {
         out += "Bollinger Bands không hợp lệ để giao dịch RANGE";
      }
      else
      {
         bool touchLower = (SymbolInfoDouble(_Symbol, SYMBOL_BID) <= (low0 + gBBTouchBufferPrice));
         bool touchUpper = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= (up0  - gBBTouchBufferPrice));
         if(!touchLower && !touchUpper)
         {
            out += StringFormat("Giá chưa chạm biên Bollinger để đánh RANGE (SymbolInfoDouble(_Symbol,SYMBOL_BID)=%s, SymbolInfoDouble(_Symbol,SYMBOL_ASK)=%s, LowBand=%s, UpBand=%s)",
                                F2(SymbolInfoDouble(_Symbol, SYMBOL_BID)), F2(SymbolInfoDouble(_Symbol, SYMBOL_ASK)), F2(low0), F2(up0));
         }
         if(rsiA > gRangeRSIBuyMax && rsiA < gRangeRSISellMin)
         {
            if(out != "") out += " | ";
            out += StringFormat("RSI chưa vào vùng RANGE (BUY cần <=%s, SELL cần >=%s; hiện tại RSI=%s)",
                                F2(gRangeRSIBuyMax), F2(gRangeRSISellMin), F2(rsiA));
         }
      }
   }
   else if(modeTag == "VOLATILE")
   {
      if(!bandsOk)
      {
         out += "Bollinger Bands không hợp lệ để giao dịch VOLATILE";
      }
      else
      {
         bool buyBreakout  = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= (up0 + gBreakoutBufferPrice))  && (rsiA >= gMomentumRSIBuyMin);
         bool sellBreakout = (SymbolInfoDouble(_Symbol, SYMBOL_BID) <= (low0 - gBreakoutBufferPrice)) && (rsiA <= gMomentumRSISellMax);
         bool rsiCrossUp50   = (rsiB < 50.0 && rsiA >= 50.0);
         bool rsiCrossDown50 = (rsiB > 50.0 && rsiA <= 50.0);
         bool buyRSI50  = (gUseRSI50Cross && atr0 >= gMinATRForRSI50Cross && upBias   && rsiCrossUp50);
         bool sellRSI50 = (gUseRSI50Cross && atr0 >= gMinATRForRSI50Cross && downBias && rsiCrossDown50);
         if(!(buyBreakout || sellBreakout || buyRSI50 || sellRSI50))
         {
            out += StringFormat("Chưa có breakout/momentum hợp lệ (ATR=%s, RSI=%s, cần BUY RSI>=%s hoặc SELL RSI<=%s)",
                                F2(atr0), F2(rsiA), F2(gMomentumRSIBuyMin), F2(gMomentumRSISellMax));
         }
      }
   }

   if(out == "")
      out = StringFormat("chưa có tín hiệu phù hợp (mode=%s, RSI=%s, ADX=%s, ATR=%s, bias=%s/%s)",
                         modeTag, F2(rsiA), F2(adx0), F2(atr0), (upBias?"UP":"-"), (downBias?"DOWN":"-"));
   return out;
}

// SR levels (simple)
bool FindRecentSRLevels(const ENUM_TIMEFRAMES tf, double &recentSwingHigh, double &recentSwingLow)
{
   recentSwingHigh = 0.0;
   recentSwingLow  = 0.0;

   int n = MathMax(InpSRLookbackBars, 30);
   double o[],h[],l[],c[];
   if(!ReadOHLC(tf, 1, n, o,h,l,c)) return false;

   int lr = MathMax(InpSwingLeftRight, 2);

   for(int i=lr; i<n-lr; i++)
   {
      if(recentSwingLow <= 0.0 && IsSwingLow(l, i, lr))
         recentSwingLow = l[i];
      if(recentSwingHigh <= 0.0 && IsSwingHigh(h, i, lr))
         recentSwingHigh = h[i];

      if(recentSwingLow>0.0 && recentSwingHigh>0.0) break;
   }
   return (recentSwingLow>0.0 || recentSwingHigh>0.0);
}

// RR Stops builder
void BuildRRStops(const ENUM_ORDER_TYPE orderType,
                  const ENUM_TIMEFRAMES tf,
                  const double entry,
                  const double atr0,
                  const double recentSwingHigh,
                  const double recentSwingLow,
                  double &sl,
                  double &tp,
                  double &rrUsed,
                  string &slBasis)
{
   sl=0.0; tp=0.0; rrUsed=0.0; slBasis="ATR";

   double slDist = 0.0;
   if(atr0 > 0.0) slDist = atr0 * MathMax(InpSL_ATR_Mult, 0.1);

   if(orderType == ORDER_TYPE_BUY)
   {
      if(recentSwingLow > 0.0)
      {
         double distSwing = entry - (recentSwingLow - InpSL_SwingBufferPrice);
         if(distSwing > 0.0)
         {
            slDist = MathMax(slDist, distSwing);
            slBasis = "SWING_LOW";
         }
      }
   }
   else
   {
      if(recentSwingHigh > 0.0)
      {
         double distSwing = (recentSwingHigh + InpSL_SwingBufferPrice) - entry;
         if(distSwing > 0.0)
         {
            slDist = MathMax(slDist, distSwing);
            slBasis = "SWING_HIGH";
         }
      }
   }

   if(InpMaxSLPriceCap > 0.0) slDist = MathMin(slDist, InpMaxSLPriceCap);

   double rr = MathMax(InpRR_Min, 1.0);
   double tpDist = slDist * rr;
   if(InpMaxTPPriceCap > 0.0) tpDist = MathMin(tpDist, InpMaxTPPriceCap);

   rrUsed = (slDist > 1e-9 ? tpDist / slDist : 0.0);

   BuildStopsFromDistance(orderType, entry, slDist, tpDist, sl, tp);
}

//==================== Price Action Confirm (minimal v4.232) ====================//
bool PriceActionConfirm(const ENUM_ORDER_TYPE orderType, const ENUM_TIMEFRAMES tf, string &paTag)
{
   paTag = "NONE";
   if(!InpUsePriceActionConfirm) return true;

   double o[1],h[1],l[1],c[1];
   if(CopyOpen(_Symbol, tf, 1, 1, o) != 1) return false;
   if(CopyHigh(_Symbol, tf, 1, 1, h) != 1) return false;
   if(CopyLow (_Symbol, tf, 1, 1, l) != 1) return false;
   if(CopyClose(_Symbol, tf, 1, 1, c) != 1) return false;

   double range = h[0] - l[0];
   if(range <= 0.0) return false;

   double body = MathAbs(c[0] - o[0]);
   double upperWick = h[0] - MathMax(o[0], c[0]);
   double lowerWick = MathMin(o[0], c[0]) - l[0];

   bool isDoji = (body <= range * MathMax(InpDojiBodyToRangeMax, 0.0));
   bool isPin  = false;

   double wb = (body > 1e-9 ? (MathMax(upperWick, lowerWick) / body) : 999.0);
   if(wb >= MathMax(InpPinbarWickBodyMin, 0.0))
      isPin = true;

   if(isDoji)
      paTag = "DOJI";
   else if(isPin)
      paTag = "PINBAR";

   if(orderType == ORDER_TYPE_BUY)
   {
      bool bullishPin = isPin && (lowerWick > upperWick) && (c[0] >= o[0]);
      bool bullishDoji = isDoji && (lowerWick >= upperWick);
      bool ok = bullishPin || bullishDoji;
      if(ok) paTag = bullishPin ? "PINBAR_BULL" : "DOJI_BULL";
      return ok;
   }
   else
   {
      bool bearishPin = isPin && (upperWick > lowerWick) && (c[0] <= o[0]);
      bool bearishDoji = isDoji && (upperWick >= lowerWick);
      bool ok = bearishPin || bearishDoji;
      if(ok) paTag = bearishPin ? "PINBAR_BEAR" : "DOJI_BEAR";
      return ok;
   }
}

//==================== DivBOS ====================//
// (giữ nguyên như v4.231)
bool DivBOS_FindSetup(ENUM_TIMEFRAMES tf, bool wantBull, int lookback, int lr,
                      double minRsiDiff,
                      double &bosHigh, double &bosLow,
                      datetime &setupBarTime)
{
   bosHigh = 0.0; bosLow = 0.0; setupBarTime = 0;

   int n = MathMax(lookback, 60);
   double o[],h[],l[],c[];
   if(!ReadOHLC(tf, 1, n, o,h,l,c)) return false;

   double rsi[];
   ArrayResize(rsi, n);
   if(CopyBuffer(hRSI, 0, 1, n, rsi) != n) return false;

   int i1=-1,i2=-1;
   if(wantBull)
   {
      for(int i=lr; i<n-lr; i++)
      {
         if(IsSwingLow(l, i, lr))
         {
            if(i1 < 0) i1 = i;
            else { i2 = i; break; }
         }
      }
      if(i1<0 || i2<0) return false;

      double low1=l[i1], low2=l[i2];
      double r1=rsi[i1], r2=rsi[i2];

      if(!(low1 > low2 && (r2 - r1) >= minRsiDiff)) return false;

      double sh = 0.0;
      for(int k=i2; k<=i1; k++)
         if(h[k] > sh) sh = h[k];

      bosHigh = sh;
      setupBarTime = GetBarOpenTime(tf, 1);
      return (bosHigh > 0.0);
   }
   else
   {
      for(int i=lr; i<n-lr; i++)
      {
         if(IsSwingHigh(h, i, lr))
         {
            if(i1 < 0) i1 = i;
            else { i2 = i; break; }
         }
      }
      if(i1<0 || i2<0) return false;

      double hi1=h[i1], hi2=h[i2];
      double r1=rsi[i1], r2=rsi[i2];

      if(!(hi1 < hi2 && (r1 - r2) >= minRsiDiff)) return false;

      double slv = 1e18;
      for(int k=i2; k<=i1; k++)
         if(l[k] < slv) slv = l[k];

      bosLow = slv;
      setupBarTime = GetBarOpenTime(tf, 1);
      return (bosLow > 0.0 && bosLow < 1e18);
   }
}

int BarsSince(datetime olderBarTime, ENUM_TIMEFRAMES tf)
{
   if(olderBarTime <= 0) return 999999;
   datetime t0 = GetBarOpenTime(tf, 0);
   if(t0 <= 0) return 999999;
   int tfSec = (int)PeriodSeconds(tf);
   if(tfSec <= 0) tfSec = 60;
   int bars = (int)((t0 - olderBarTime) / tfSec);
   if(bars < 0) bars = 0;
   return bars;
}

bool DivBOS_CheckBreak(ENUM_TIMEFRAMES tf, int dir, double bosHigh, double bosLow, bool closedBreak)
{
   double px = 0.0;
   if(closedBreak)
   {
      double c1=0;
      if(!GetCloseTF(tf, 1, c1)) return false;
      px = c1;
   }
   else
   {
      px = (dir>0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   }

   if(dir > 0) return (bosHigh > 0.0 && px > bosHigh);
   if(dir < 0) return (bosLow  > 0.0 && px < bosLow);
   return false;
}

//+------------------------------------------------------------------+
//| Scalping Pro Gate                                                 |
//+------------------------------------------------------------------+
string MarketStateTag(bool isSideways, bool isVolatile, bool trendOk, double adx0, double atr0, ENUM_TREND_DIR tf1, ENUM_TREND_DIR tf2)
{
   if(isVolatile && adx0 < gADXSidewaysMax) return "BIEN_DONG_NHIEU";
   if(isSideways) return "DANG_TICH_LUY";
   if(trendOk && (tf1==TREND_UP || tf1==TREND_DOWN)) return "XU_HUONG_RO_RANG";
   if(atr0 >= gATRHighThreshold) return "BIEN_DONG";
   return "TRUNG_TINH";
}

bool ScalpingProGate(const ENUM_ORDER_TYPE orderType,
                     const ENUM_TIMEFRAMES tf,
                     const string modeTag,
                     const double rsiA,
                     const double adx0,
                     const double atr0,
                     const bool bandsOk,
                     const double bbUp,
                     const double bbMid,
                     const double bbLow,
                     string &outMarketState,
                     string &outDecision,
                     string &outReason,
                     bool &outDiv,
                     string &outPA,
                     bool &outSRok,
                     bool &outSRSoftTriggered,
                     ENUM_TREND_DIR &t1,
                     ENUM_TREND_DIR &t2,
                     double &ema21_tf,
                     double &ema50_tf,
                     double &stK,
                     double &stD)
{
   bool buy = (orderType == ORDER_TYPE_BUY);

   outMarketState="";
   outDecision="OUT";
   outReason="";
   outDiv=false;
   outPA="NONE";
   outSRok=false;
   outSRSoftTriggered=false;

   ema21_tf=0;
   ema50_tf=0;
   stK=0;
   stD=0;

   if(!InpEnableScalpingProLayer)
      return true;

   bool tfFollow = IsTrendFollowContext(modeTag);

   //================ TREND =================//

   t1 = TrendByEMA(InpTrendTF1, hEMA21_TF1, hEMA50_TF1);
   t2 = TrendByEMA(InpTrendTF2, hEMA21_TF2, hEMA50_TF2);

   bool trendAlignOk=true;

   if(InpRequireMTFTrendAlign)
   {
      if(UseStrictMTF())
         trendAlignOk = buy ? (t1==TREND_UP && t2==TREND_UP)
                            : (t1==TREND_DOWN && t2==TREND_DOWN);
      else
         trendAlignOk = buy ? (t1==TREND_UP || t2==TREND_UP)
                            : (t1==TREND_DOWN || t2==TREND_DOWN);
   }

   //================ EMA =================//

   bool emaDataOk=true;
   bool emaGateOk=true;

   double cl=0;

   if(InpUseEMA21_50Filter)
   {
      emaDataOk =
         GetEMA(hEMA21_TF,1,ema21_tf) &&
         GetEMA(hEMA50_TF,1,ema50_tf) &&
         GetCloseTF(tf,1,cl);

      if(emaDataOk)
      {
         if(buy)
            emaGateOk = (cl >= ema21_tf) || (t1==TREND_UP);
         else
            emaGateOk = (cl <= ema21_tf) || (t1==TREND_DOWN);
      }
   }

   //================ STOCH =================//

   bool stochOk=true;

   if(InpUseStochFilter)
   {
      double k0,k1,k2,d0,d1,d2;

      stochOk = ReadStoch(k0,k1,k2,d0,d1,d2);

      if(stochOk)
      {
         stK=k1;
         stD=d1;

         if(tfFollow)
         {
            bool crossUp   = (k2<=d2 && k1>d1);
            bool crossDown = (k2>=d2 && k1<d1);

            if(buy)
               stochOk = ((k1>d1) && (k1>=EffectiveTFStochBuyMinK()))
                        || (crossUp && k1>=EffectiveTFStochBuyCrossMinK());
            else
               stochOk = ((k1<d1) && (k1<=EffectiveTFStochSellMaxK()))
                        || (crossDown && k1<=EffectiveTFStochSellCrossMaxK());
         }
         else
         {
            if(buy)
               stochOk = (k1<=InpStochOversold) || (k1>d1 && k2<=d2);
            else
               stochOk = (k1>=InpStochOverbought) || (k1<d1 && k2>=d2);
         }
      }
   }

   //================ RSI =================//

   bool rsiOk=true;

   if(InpUseRSI_OBOS_Filter && !tfFollow)
   {
      if(buy)
         rsiOk = (rsiA <= InpRSI_OS) || (rsiA <= gRSIOversold);
      else
         rsiOk = (rsiA >= InpRSI_OB) || (rsiA >= gRSIOverbought);
   }

   //================ PRICE ACTION =================//

   bool paOk=true;

   if(InpUsePriceActionConfirm)
      paOk = PriceActionConfirm(orderType,tf,outPA);

   //================ SR =================//

   bool srOk=true;
   double srH=0;
   double srL=0;

   if(InpUseSRConfirm && InpSRMode!=SR_OFF)
   {
      if(!tfFollow)
      {
         srOk = FindRecentSRLevels(tf,srH,srL);

         if(srOk)
         {
            double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
            double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

            if(buy)
               srOk = (srL>0 && MathAbs(bid-srL)<=InpSRBufferPrice);
            else
               srOk = (srH>0 && MathAbs(ask-srH)<=InpSRBufferPrice);
         }
      }
   }

   outSRok=srOk;

   //================ MARKET STATE =================//

   bool isVolatile = (gEnableVolatilityMode && atr0>=gATRHighThreshold);
   bool isSideways = (gEnableSidewaysMode && adx0>0 && adx0<gADXSidewaysMax);
   bool trendOk = (t1!=TREND_UNKNOWN || t2!=TREND_UNKNOWN);

   outMarketState =
      MarketStateTag(isSideways,isVolatile,trendOk,adx0,atr0,t1,t2);

   //================ FINAL GATE =================//

   bool ok=true;
   string reasons="";

   if(InpRequireMTFTrendAlign && !trendAlignOk)
   {
      ok=false;
      reasons+="MTFTrendNoAlign;";
   }

   if(InpUseEMA21_50Filter && !emaGateOk)
   {
      ok=false;
      reasons+="EMAGateFail;";
   }

   if(InpUseStochFilter && !stochOk)
   {
      ok=false;
      reasons+="StochFail;";
   }

   if(InpUseRSI_OBOS_Filter && !tfFollow && !rsiOk)
   {
      ok=false;
      reasons+="RSIFail;";
   }

   if(InpUsePriceActionConfirm && !paOk)
   {
      ok=false;
      reasons+="PAFail;";
   }

   if(InpUseSRConfirm && !tfFollow && InpSRMode!=SR_OFF)
   {
      if(!srOk)
      {
         if(InpSRMode==SR_HARD)
         {
            ok=false;
            reasons+="SRFail;";
         }
         else if(UseSRFilter())
         {
            outSRSoftTriggered=true;
            reasons+="SRSoft;";
         }
      }
   }

   //================ FALLBACK =================//

   if(!ok && reasons=="")
   {
      reasons = StringFormat(
         "GateFail(RSI=%.2f,ADX=%.2f,ATR=%.2f,BB=%s)",
         rsiA,
         adx0,
         atr0,
         bandsOk?"OK":"FAIL"
      );
   }

   outReason=reasons;
   outDecision = ok ? (buy ? "BUY":"SELL") : "OUT";

   return ok;
}

//+------------------------------------------------------------------+
//| Attempt entry                                                     |
//+------------------------------------------------------------------+
void AttemptEntry(const ENUM_ORDER_TYPE orderType,
                  const double rsiA,
                  const double atr0,
                  const string modeTag,
                  const double adx0,
                  const bool bandsOk,
                  const double bbUp,
                  const double bbMid,
                  const double bbLow,
                  const bool envTightNow)
{
   UpdateFinalEffectiveParams();
   if(InpAggressiveMode){ eMinSecondsBetweenEntries=5; /* Aggressive override handled via local variable */ /* Aggressive override handled via local variable */ }
string pauseWhy = "";
   if(IsTradePausedByLossStreak(pauseWhy))
   {
      Log(pauseWhy);
      return;
   }
   if(IsTradePausedByDrawdown(pauseWhy))
   {
      Log(pauseWhy);
      return;
   }

   // --- v4.232: env tightening differs by TrendMode (avoid impossible RSI) ---
   // Base: still slow down in bad env if ForceTrendEverywhere
   if(InpForceTrendEverywhere && envTightNow)
   {
      // generic slow down
      eMinSecondsBetweenEntries   = MathMax(eMinSecondsBetweenEntries, 20);
      eMinMinutesBetweenPositions = MathMax(eMinMinutesBetweenPositions, 2);

      // extra for PULLBACK (no lock): further slow down + cap max open in this attempt
      if(gTrendMode == TREND_PULLBACK)
      {
         eMinSecondsBetweenEntries   = MathMax(eMinSecondsBetweenEntries, 20 + MathMax(InpTightPullback_ExtraGapSec,0));
         eMinMinutesBetweenPositions = MathMax(eMinMinutesBetweenPositions, 2 + MathMax(InpTightPullback_ExtraGapMin,0));
      }
   }

   // --- Advanced entry blocks ---
   string blockWhy="";
   if(IsEntryBlockedNow(atr0, blockWhy))
   {
      datetime retryTime = 0;
      if(blockWhy == "Chặn trước phiên")
         retryTime = NextAllowedTradeTime_PreSession();
      else if(blockWhy == "Chặn trước/sau tin tức")
         retryTime = NextAllowedTradeTime_News();
      LogBlockedOnceWithRetry(blockWhy, retryTime);
      return;
   }

   // --- Tight-session ATR ceiling ---
   if(eTightSession && InpTightMaxATRToAllowEntry > 0.0 && atr0 > InpTightMaxATRToAllowEntry)
   {
      LogBlockedOnce(StringFormat("ATR phiên siết quá cao (%.2f > %.2f)", atr0, InpTightMaxATRToAllowEntry));
      return;
   }

   datetime now = TimeCurrent();
   if(!gTradeOnNewBar)
   {
      if((now - lastEntryAttemptTime) < eMinSecondsBetweenEntries)
         return;
   }
   lastEntryAttemptTime = now;

   // Hedge block
   if(InpEnablePyramidingSafe && InpBlockHedgeAlways)
   {
      if(HasOppositePositionThisEA(orderType))
      {
         LogBlockedOnce("Đang có vị thế ngược chiều");
         return;
      }
   }

   if(EffectiveMaxOpen() <= 1)
      CloseOppositeIfAny(orderType);

   if(!CheckMinMinutesBetweenPositions())
   {
      LogBlockedOnce(StringFormat("Chưa đủ khoảng cách thời gian giữa các lệnh (%d phút)", EffectiveMinMinutesBetweenPositions()));
      return;
   }

   // --- v4.232: local maxOpen cap in special tightening (Pullback env tight) ---
   int effMaxOpen = EffectiveMaxOpen();
   if(InpForceTrendEverywhere && envTightNow && gTrendMode == TREND_PULLBACK && InpTightPullback_MaxOpenCap > 0)
      effMaxOpen = MathMin(effMaxOpen, InpTightPullback_MaxOpenCap);

   if(CountOpenPositionsThisEA() >= effMaxOpen)
   {
      LogBlockedOnce(StringFormat("Đã đạt số lệnh tối đa (%d/%d)", CountOpenPositionsThisEA(), effMaxOpen));
      return;
   }

   // Trade environment (reason + spread dyn)
   string envWhy="";
   int spreadPts=-1;
   if(!CheckTradeEnvironment(atr0, envWhy, spreadPts))
   {
      if(envWhy == "Ngoài giờ giao dịch")
         LogBlockedOnceWithRetry(envWhy, NextAllowedTradeTime_TimeFilter());
      else if(envWhy == "NoBidAsk")
         LogBlockedOnce("Không có giá SymbolInfoDouble(_Symbol,SYMBOL_BID)/SymbolInfoDouble(_Symbol,SYMBOL_ASK) hợp lệ");
      else if(StringFind(envWhy, "SpreadTooHigh") >= 0)
         LogBlockedOnce(StringFormat("Spread quá cao (%d points)", spreadPts));
      else if(envWhy == "TerminalTradeNotAllowed")
         LogBlockedOnce("Terminal không cho phép giao dịch");
      else if(envWhy == "MQLTradeNotAllowed")
         LogBlockedOnce("MQL không cho phép giao dịch");
      else if(envWhy == "SymbolTradeDisabled")
         LogBlockedOnce("Symbol bị chặn giao dịch");
      else
         LogBlockedOnce(envWhy);
      return;
   }

   // Pyramiding Safe Gate
   // v4.232: if Pullback + envTight => block any add-ons (only first entry) to stay safe but not lock signals.
   if(InpForceTrendEverywhere && envTightNow && gTrendMode==TREND_PULLBACK)
   {
      if(CountOpenPositionsThisEA() > 0)
      {
         LogBlockedOnce("Môi trường siết chặt: không cho nhồi thêm lệnh");
         return;
      }
   }

   string pyrWhy="";
   if(!CanPyramidSafe(orderType, modeTag, atr0, pyrWhy))
   {
      LogBlockedOnce("Điều kiện pyramiding không đạt: " + pyrWhy);
      return;
   }

   // -------- Scalping Pro Gate --------
   string marketState="", decision="OUT", reason="", pa="NONE";
   bool div=false, srOk=false, srSoft=false;
   ENUM_TREND_DIR t1=TREND_UNKNOWN, t2=TREND_UNKNOWN;
   double ema21_tf=0, ema50_tf=0, stK=0, stD=0;

   bool gateOk = ScalpingProGate(orderType, CalcTF(), modeTag, rsiA, adx0, atr0, bandsOk, bbUp, bbMid, bbLow,
                                 marketState, decision, reason, div, pa, srOk, srSoft, t1, t2, ema21_tf, ema50_tf, stK, stD);
   gateOk = FrequencyAdaptiveGate(gateOk);

if(InpEnableLiquidityMap)
   gateOk = gateOk && DetectLiquiditySweepMultiSwing();

if(InpEnableAIVolatilityRegime)
{
   int vr = GetAIVolatilityRegime();
   if(vr==0) gateOk=false;
}

if(!IsSmartSessionActive())
   gateOk=false;

   gateOk = AggressiveEntryOverride(gateOk);

   // ANALYSIS log throttle
   if(InpEnableScalpingProLayer && InpLogAnalysisEverySignal)
   {
      string gateDir = (orderType==ORDER_TYPE_BUY ? "BUY" : "SELL");

      datetime barT = GetBarOpenTime(CalcTF(), 0);
      bool newBar = (barT != 0 && barT != gLastAnalysisBarTime);

      string key = StringFormat("%s|%s|%s|%s|%s|%s|envTight=%s",
                                gateDir, marketState, (gateOk?decision:"OUT"), modeTag,
                                (bandsOk?"BB_OK":"BB_BAD"), reason, (envTightNow?"true":"false"));

      bool changed = (key != gLastAnalysisKey);

      if(newBar || changed)
      {
         if(barT!=0) gLastAnalysisBarTime = barT;
         gLastAnalysisKey = key;

         Log(StringFormat("ANALYSIS: GateDir=%s | State=%s | Decision=%s | mode=%s | TF=%s | Trend(%s)=%s Trend(%s)=%s | EMA21=%.2f EMA50=%.2f | RSI=%.2f | StochK=%.2f D=%.2f | PA=%s | BB(%s)[U=%.2f M=%.2f L=%.2f] | ADX=%.2f ATR=%.2f | Spread=%d pts | envTight=%s | Reason=%s",
                          gateDir,
                          marketState, (gateOk?decision:"OUT"), modeTag, EnumToString(CalcTF()),
                          EnumToString(InpTrendTF1), TrendToString(t1),
                          EnumToString(InpTrendTF2), TrendToString(t2),
                          ema21_tf, ema50_tf, rsiA, stK, stD,
                          pa,
                          (bandsOk?"OK":"INVALID"),
                          bbUp, bbMid, bbLow,
                          adx0, atr0, spreadPts,
                          (envTightNow?"true":"false"),
                          reason));
      }
   }

   if(!gateOk)
   {
      string techReason = BuildTechnicalFailReason(orderType, modeTag,
                                                   rsiA, adx0, atr0, bandsOk, bbUp, bbMid, bbLow,
                                                   t1, t2, ema21_tf, ema50_tf, stK, stD, reason);
      LogBlockedOnce("Điều kiện kỹ thuật không đạt: " + techReason);
      return;
   }

   // --- v4.232: SR_SOFT risk-tightening (no full lock) ---
   if(srSoft)
   {
      int cap = (InpSRSoft_MaxOpenCap > 0 ? InpSRSoft_MaxOpenCap : 1);
      if(CountOpenPositionsThisEA() >= MathMin(effMaxOpen, cap))
      {
         LogBlockedOnce(StringFormat("SR soft giới hạn số lệnh tối đa (%d/%d)", CountOpenPositionsThisEA(), MathMin(effMaxOpen, cap)));
         return;
      }
      // apply additional spacing for safety
      // (we cannot retroactively change lastEntryAttemptTime, but we can enforce a manual wait)
      datetime latestPosTime = GetLatestPositionOpenTimeThisEA();
      if(latestPosTime <= 0) latestPosTime = gLastOpenTimeThisEA;
      if(latestPosTime > 0)
      {
         long needSec = (long)MathMax(InpSRSoft_ExtraGapMin,0) * 60;
         long passed  = (long)(TimeCurrent() - latestPosTime);
         if(passed < needSec)
         {
            LogBlockedOnce(StringFormat("SR soft chưa đủ thời gian chờ (%ds/%ds)", passed, needSec));
            return;
         }
      }
   }

   // -------- Stops --------
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double entryRef = (orderType == ORDER_TYPE_BUY) ? ask : bid; // chỉ để tính SL/TP

   double sl=0.0, tp=0.0;

   bool useRR = (InpEnableScalpingProLayer && InpUseRRStops);
   if(InpFixStops && !InpAllowRROverrideFixStops)
      useRR = false;

   double baseSL=0.0, baseTP=0.0;

   if(useRR)
   {
      double srH=0.0,srL=0.0;
      FindRecentSRLevels(CalcTF(), srH, srL);

      double rrUsed=0.0; string slBasis="";
      BuildRRStops(orderType, CalcTF(), entryRef, atr0, srH, srL, baseSL, baseTP, rrUsed, slBasis);

      if(!CheckStopsDistance(entryRef, baseSL, baseTP))
      {
         double slDist=0.0, tpDist=0.0;
         CalcStopDistances(modeTag, atr0, slDist, tpDist);
         BuildStopsFromDistance(orderType, entryRef, slDist, tpDist, baseSL, baseTP);
      }
   }
   else
   {
      double slDist=0.0, tpDist=0.0;
      CalcStopDistances(modeTag, atr0, slDist, tpDist);
      BuildStopsFromDistance(orderType, entryRef, slDist, tpDist, baseSL, baseTP);
   }

   double targetRR = DeriveTargetRR(entryRef, baseSL, baseTP);
   targetRR = ApplyVolatilityAdjustedRR(targetRR, atr0);

   string slWhy = "";
   double slBufferPrice = 0.0;
   if(!BuildHybridSL(orderType, CalcTF(), entryRef, atr0, sl, slBufferPrice, slWhy))
   {
      LogBlockedOnce("Hybrid StopLoss không hợp lệ: " + slWhy);
      return;
   }

   double slDist = MathAbs(entryRef - sl);
   if(slDist <= 0.0)
   {
      LogBlockedOnce("Khoảng cách StopLoss theo nến tín hiệu không hợp lệ");
      return;
   }

   tp = (orderType == ORDER_TYPE_BUY)
        ? NormalizeToTick(entryRef + (slDist * targetRR))
        : NormalizeToTick(entryRef - (slDist * targetRR));
   tp = BlendTPWithFib(orderType, CalcTF(), entryRef, tp);

   if(!EnsureSLMeetsBrokerStopLevel(orderType, entryRef, sl))
   {
      LogBlockedOnce("Không thể căn chỉnh StopLoss theo StopLevel của broker");
      return;
   }

   if(!CheckStopsDistance(entryRef, sl, tp))
   {
      int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double minDist = (stopsLevel > 0 ? stopsLevel * point : 0.0);
      if(minDist > 0.0)
      {
         tp = (orderType == ORDER_TYPE_BUY)
              ? NormalizeToTick(entryRef + MathMax(minDist, slDist * targetRR))
              : NormalizeToTick(entryRef - MathMax(minDist, slDist * targetRR));
      }

      if(!CheckStopsDistance(entryRef, sl, tp))
      {
         LogBlockedOnce("StopLoss/TakeProfit không hợp lệ sau khi dựng lại theo StopLevel");
         return;
      }
   }

   double lots = NormalizeVolume(gFixedLot * EffectiveLotMultiplierByDrawdown());
   double lossMoney=0.0, maxLossMoney=0.0;
   bool riskOk = ValidateRiskForFixedLot(orderType, lots, entryRef, sl, lossMoney, maxLossMoney);
   if(InpBlockTradeIfRiskTooHigh && !riskOk)
   {
      LogBlockedOnce(StringFormat("Rủi ro vượt ngưỡng: lot=%.2f lỗ dự kiến=%.2f > cho phép=%.2f (%.2f%%)",
                       lots, lossMoney, maxLossMoney, EffectiveRiskPercent()));
      return;
   }

   // Notify signal
   if(InpNotifyOnSignal)
   {
      string dir = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      double rrNow = 0.0;
      if(sl > 0.0 && tp > 0.0)
      {
         double risk = MathAbs(entryRef - sl);
         double rew  = MathAbs(tp - entryRef);
         rrNow = (risk > 1e-9 ? (rew / risk) : 0.0);
      }

      Notify(StringFormat("Decision=%s | State=%s | %s [%s] %s TF=%s | RefEntry=%.2f SL=%.2f TP=%.2f RR=%.2f | RSI=%.2f StochK=%.2f | PA=%s | MaxOpen=%d",
                          dir, marketState, dir, modeTag, _Symbol, EnumToString(CalcTF()),
                          entryRef, sl, tp, rrNow,
                          rsiA, stK, pa,
                          effMaxOpen));
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(gSlippagePoints);

   // IMPORTANT: market order with price=0
   ResetLastError();
   bool ok = (orderType==ORDER_TYPE_BUY)
             ? trade.Buy(lots, _Symbol, 0.0, sl, tp, modeTag + " BUY")
             : trade.Sell(lots, _Symbol, 0.0, sl, tp, modeTag + " SELL");

   int err = _LastError;

   if(ok)
   {
      gLastOpenTimeThisEA = TimeCurrent();

      if(InpNotifyOnOrderResult)
         Notify(StringFormat("ORDER OK: %s %s [%s] lots=%.2f SL=%.2f TP=%.2f | OpenNow=%d/%d",
                             (orderType==ORDER_TYPE_BUY?"BUY":"SELL"),
                             _Symbol, modeTag, lots, sl, tp,
                             CountOpenPositionsThisEA(), effMaxOpen));
      LogOnce("Order placed successfully (market price=0). Waiting fill deal for actual entry price...");
   }
   else
   {
      if(InpNotifyOnOrderResult)
         Notify(StringFormat("ORDER FAIL: %s %s [%s] ret=%d (%s) err=%d",
                             (orderType==ORDER_TYPE_BUY?"BUY":"SELL"), _Symbol, modeTag,
                             (int)trade.ResultRetcode(), trade.ResultRetcodeDescription(), err));
      Log(StringFormat("Order failed. ret=%d (%s) err=%d",
                       (int)trade.ResultRetcode(), trade.ResultRetcodeDescription(), err));
   }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction: log ENTRY filled + CLOSE reason               |
//+------------------------------------------------------------------+
string DealReasonToString(const long reason)
{
   string s = EnumToString((ENUM_DEAL_REASON)reason);
   if(s == "DEAL_REASON_SL")        return "SL";
   if(s == "DEAL_REASON_TP")        return "TP";
   if(s == "DEAL_REASON_SO")        return "STOP_OUT";
   if(s == "DEAL_REASON_ROLLOVER")  return "ROLLOVER";
   if(s == "DEAL_REASON_CLIENT")    return "CLIENT";
   if(s == "DEAL_REASON_EXPERT")    return "EXPERT";
   return s;
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong deal = trans.deal;
   if(deal == 0) return;

   string sym = (string)HistoryDealGetString(deal, DEAL_SYMBOL);
   if(sym != _Symbol) return;

   long magic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
   if(magic != InpMagicNumber) return;

   long entry = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
   long dtype = (long)HistoryDealGetInteger(deal, DEAL_TYPE);

   double price = (double)HistoryDealGetDouble(deal, DEAL_PRICE);
   double vol   = (double)HistoryDealGetDouble(deal, DEAL_VOLUME);
   double profit= (double)HistoryDealGetDouble(deal, DEAL_PROFIT);
   ulong posId  = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   string comment = (string)HistoryDealGetString(deal, DEAL_COMMENT);

   string side = (dtype==DEAL_TYPE_SELL ? "SELL" : (dtype==DEAL_TYPE_BUY ? "BUY" : "OUT"));

   // log actual filled entry
   if(entry == DEAL_ENTRY_IN)
   {
      gLastOpenTimeThisEA = TimeCurrent();
      LogTag("ENTRY", StringFormat("ENTRY FILLED: posId=%I64u side=%s vol=%.2f entryPrice=%.2f comment='%s'",
                       posId, side, vol, price, comment));
      ExportTradeCSV("ENTRY", posId, side, vol, price, 0.0, "ENTRY", comment);
      return;
   }

   if(entry != DEAL_ENTRY_OUT) return;

   long reason = (long)HistoryDealGetInteger(deal, DEAL_REASON);
   string base = DealReasonToString(reason);
   string extra = "";

   if(base == "SL")
   {
      if(ArraySize(gTrailTickets) > 0)
         extra = " (possible TRAILING)";
   }

   LogTag("EXIT", StringFormat("POSITION CLOSED: posId=%I64u side=%s vol=%.2f closePrice=%.2f profit=%.2f reason=%s%s comment='%s'",
                    posId, side, vol, price, profit, base, extra, comment));
   ExportTradeCSV("EXIT", posId, side, vol, price, profit, base + extra, comment);

   UpdateLossPauseStateByClosedProfit(profit);

   for(int i=ArraySize(gTrailTickets)-1; i>=0; --i)
   {
      ulong t = gTrailTickets[i];
      if(!PositionSelectByTicket(t)) TrailMarkRemove(t);
   }
   for(int j=ArraySize(gCloseReqTickets)-1; j>=0; --j)
   {
      ulong t2 = gCloseReqTickets[j];
      if(!PositionSelectByTicket(t2)) CloseReqRemove(t2);
   }
   for(int k=ArraySize(gRecTickets)-1; k>=0; --k)
   {
      ulong t3 = gRecTickets[k];
      if(!PositionSelectByTicket(t3)) RecRemove(t3);
   }
   for(int m=ArraySize(gPartialTickets)-1; m>=0; --m)
   {
      ulong t4 = gPartialTickets[m];
      if(!PositionSelectByTicket(t4)) PartialMarkRemove(t4);
   }
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   gInstanceId = StringFormat("%I64X-%X", (long)ChartID(), (uint)GetTickCount());
   trade.SetExpertMagicNumber(InpMagicNumber);

   ApplyPreset();
   ApplyHighFrequencyOverrides();
   UpdateFinalEffectiveParams();
   if(InpAggressiveMode){ eMinSecondsBetweenEntries=5; /* Aggressive override handled via local variable */ /* Aggressive override handled via local variable */ }
gPeakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   gPeakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);

   ENUM_TIMEFRAMES tf = CalcTF();

   hFastMA = iMA(_Symbol, tf, gFastMAPeriod, 0, InpMAMethod, InpMAPrice);
   hSlowMA = iMA(_Symbol, tf, gSlowMAPeriod, 0, InpMAMethod, InpMAPrice);
   hRSI    = iRSI(_Symbol, tf, gRSIPeriod, PRICE_CLOSE);
   hADX    = iADX(_Symbol, tf, gADXPeriod);
   hBands  = iBands(_Symbol, tf, gBBPeriod, 0, gBBDeviation, InpMAPrice);
   hATR_regime = iATR(_Symbol, tf, gATRPeriod);

   hEMA21_TF  = iMA(_Symbol, tf, InpEMA21, 0, MODE_EMA, PRICE_CLOSE);
   hEMA50_TF  = iMA(_Symbol, tf, InpEMA50, 0, MODE_EMA, PRICE_CLOSE);

   hEMA21_TF1 = iMA(_Symbol, InpTrendTF1, InpEMA21, 0, MODE_EMA, PRICE_CLOSE);
   hEMA50_TF1 = iMA(_Symbol, InpTrendTF1, InpEMA50, 0, MODE_EMA, PRICE_CLOSE);
   hEMA21_TF2 = iMA(_Symbol, InpTrendTF2, InpEMA21, 0, MODE_EMA, PRICE_CLOSE);
   hEMA50_TF2 = iMA(_Symbol, InpTrendTF2, InpEMA50, 0, MODE_EMA, PRICE_CLOSE);

   hStoch = iStochastic(_Symbol, tf, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   hIchimoku = iIchimoku(_Symbol, tf, InpIchimokuTenkan, InpIchimokuKijun, InpIchimokuSenkouB);

   if(hFastMA==INVALID_HANDLE || hSlowMA==INVALID_HANDLE || hRSI==INVALID_HANDLE ||
      hADX==INVALID_HANDLE || hBands==INVALID_HANDLE || hATR_regime==INVALID_HANDLE)
   {
      LogTag("START", "INIT_FAILED: base indicator handles");
      return INIT_FAILED;
   }

   if(InpEnableScalpingProLayer)
   {
      if(hEMA21_TF==INVALID_HANDLE || hEMA50_TF==INVALID_HANDLE ||
         hEMA21_TF1==INVALID_HANDLE || hEMA50_TF1==INVALID_HANDLE ||
         hEMA21_TF2==INVALID_HANDLE || hEMA50_TF2==INVALID_HANDLE ||
         (InpUseStochFilter && hStoch==INVALID_HANDLE) || (InpUseIchimokuBiasFilter && hIchimoku==INVALID_HANDLE))
      {
         LogTag("START", "INIT_FAILED: scalping-pro indicator handles");
         return INIT_FAILED;
      }
   }

   datetime t[1];
   if(CopyTime(_Symbol, tf, 0, 1, t) == 1) lastBarTime = t[0];

   gLastAnalysisBarTime = GetBarOpenTime(tf, 0);
   gLastAnalysisKey = "";

   gDivBOS.active=false; gDivBOS.dir=0; gDivBOS.refHigh=0; gDivBOS.refLow=0; gDivBOS.bornBarTime=0;

   LogTag("START", StringFormat("v4.236 init. Preset=%s | ForceTrendEverywhere=%s | HFMode=%s | TrendMode=%s | FixStops=%s (RRoverride=%s) | ClosedBarSignals(eff)=%s | GapBase=%dmin GapEff=%dmin | MaxOpen=%d (OnePos=%s) | HedgeBlock=%s | PyramidSafe=%s | DivBOS=%s | SRMode=%s",
                    (InpPresetMode==PRESET_AUTO?"AUTO":"MANUAL"),
                    (InpForceTrendEverywhere?"true":"false"),
                    (gHighFrequencyMode?"true":"false"),
                    (gTrendMode==TREND_FOLLOW?"TREND_FOLLOW":"PULLBACK"),
                    (InpFixStops?"true":"false"),
                    (InpAllowRROverrideFixStops?"true":"false"),
                    (gUseClosedBarSignals?"true":"false"),
                    gMinMinutesBetweenPositions,
                    EffectiveMinMinutesBetweenPositions(),
                    EffectiveMaxOpen(),
                    (InpOnePositionPerSymbol?"true":"false"),
                    (InpBlockHedgeAlways?"true":"false"),
                    (InpEnablePyramidingSafe?"true":"false"),
                    (InpEnableDivBOS?"true":"false"),
                    (InpSRMode==SR_OFF?"OFF":(InpSRMode==SR_HARD?"HARD":"SOFT"))));

   LogTag("START", StringFormat("RiskGate fixedLot=%.2f maxRisk=%.2f%% blockRisk=%s | SpreadGuard=%d abnormal=%s x%.2f | News=%d/%d | HF=%s Boost=%d | Pyramid=%s | LossPause=%d losses/%d min",
                    InpFixedLot, EffectiveRiskPercent(), (InpBlockTradeIfRiskTooHigh?"true":"false"),
                    InpMaxSpreadPoints, (InpUseDynamicSpreadAbnormalBlock?"true":"false"), MathMax(InpSpreadAbnormalMultiplier,1.1),
                    InpNewsBlockBefore_Min, InpNewsBlockAfter_Min,
                    (InpHighFrequencyMode?"true":"false"), (int)InpFrequencyMode,
                    (InpEnablePyramidingSafe?"true":"false"),
                    InpMaxConsecutiveLosses, InpPauseAfterLosses_Min));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hFastMA != INVALID_HANDLE) IndicatorRelease(hFastMA);
   if(hSlowMA != INVALID_HANDLE) IndicatorRelease(hSlowMA);
   if(hRSI    != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hADX    != INVALID_HANDLE) IndicatorRelease(hADX);
   if(hBands  != INVALID_HANDLE) IndicatorRelease(hBands);
   if(hATR    != INVALID_HANDLE) IndicatorRelease(hATR);

   if(hEMA21_TF  != INVALID_HANDLE) IndicatorRelease(hEMA21_TF);
   if(hEMA50_TF  != INVALID_HANDLE) IndicatorRelease(hEMA50_TF);
   if(hEMA21_TF1 != INVALID_HANDLE) IndicatorRelease(hEMA21_TF1);
   if(hEMA50_TF1 != INVALID_HANDLE) IndicatorRelease(hEMA50_TF1);
   if(hEMA21_TF2 != INVALID_HANDLE) IndicatorRelease(hEMA21_TF2);
   if(hEMA50_TF2 != INVALID_HANDLE) IndicatorRelease(hEMA50_TF2);
   if(hStoch     != INVALID_HANDLE) IndicatorRelease(hStoch);

   LogOnce(StringFormat("Deinit reason=%d", reason));
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateFrequencyBoostSettings();
   ApplyRecoveryProfitClose();
   ApplyBreakEvenLogic();
   ApplyTrailing();
   ApplyPartialCloseLogic();

   double bid0 = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask0 = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point0 = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point0 > 0.0 && bid0 > 0.0 && ask0 > 0.0 && ask0 >= bid0)
      UpdateSpreadTelemetry((int)MathRound((ask0 - bid0) / point0));

   if(gTradeOnNewBar)
   {
      if(!IsNewBar()) return;
   }

   double f0,f1,f2, s0,s1,s2;
   double r0,r1,r2;
   double adx0=0, atr0=0;

   if(!ReadMA(f0,f1,f2,s0,s1,s2) || !ReadRSI(r0,r1,r2) || !ReadATR(atr0))
      return;

   bool adxOk = ReadADX(adx0);

   double up0=0, mid0=0, low0=0;
   bool bandsOk = ReadBands(up0, mid0, low0);

   double fastA, fastB, slowA, slowB;
   double rsiA, rsiB;

   if(gUseClosedBarSignals)
   {
      fastA = f1; fastB = f2;
      slowA = s1; slowB = s2;
      rsiA  = r1; rsiB  = r2;
   }
   else
   {
      fastA = f0; fastB = f1;
      slowA = s0; slowB = s1;
      rsiA  = r0; rsiB  = r1;
   }

   double biasDist = MathAbs(fastA - slowA);
   bool biasStrong = true;
   if(gBiasMinDistancePrice > 0.0)
      biasStrong = (biasDist >= gBiasMinDistancePrice);

   bool upBias   = (fastA > slowA) && biasStrong;
   bool downBias = (fastA < slowA) && biasStrong;

   bool isVolatile = (gEnableVolatilityMode && atr0 >= gATRHighThreshold);

   bool sidewaysByAdx = (gEnableSidewaysMode && adxOk && adx0 < gADXSidewaysMax);
   double bbWidth = (bandsOk ? (up0 - low0) : 0.0);
   bool sidewaysByBB  = (!InpUseBBWidthForSideways) || (bandsOk && bbWidth > 0.0 && bbWidth <= InpMaxBBWidthPrice);
   bool isSideways = (sidewaysByAdx && sidewaysByBB);

   bool envTightNow = (isSideways || isVolatile);

   bool crossUp   = (fastB <= slowB && fastA > slowA);
   bool crossDown = (fastB >= slowB && fastA < slowA);

   bool recentCrossUp   = crossUp;
   bool recentCrossDown = crossDown;
   if(EffectivePullbackRecentCrossBars() >= 2)
   {
      if((f2 <= s2 && f1 > s1) || (f1 <= s1 && f0 > s0) || crossUp) recentCrossUp = true;
      if((f2 >= s2 && f1 < s1) || (f1 >= s1 && f0 < s0) || crossDown) recentCrossDown = true;
   }

   bool trendAdxOk = true;
   if(gUseTrendAdxFloor)
      trendAdxOk = (adxOk && adx0 >= (gADXSidewaysMax + gTrendAdxBuffer));

   bool buyTrend=false, sellTrend=false;

   if(InpAutoTrendModeByTF)
      gTrendMode = EffectiveTrendModeByTF();

   // ======== Core TREND logic (PRO-MTF: M1-M5 follow trend, M15+ pullback) ========
   if(gTrendMode == TREND_PULLBACK)
   {
      double rsiBuyPullback  = EffectivePullbackBuyRSIMax();
      double rsiSellPullback = EffectivePullbackSellRSIMin();

      if(InpForceTrendEverywhere)
      {
         buyTrend  = upBias   && recentCrossUp   && (rsiA <= rsiBuyPullback);
         sellTrend = downBias && recentCrossDown && (rsiA >= rsiSellPullback);
      }
      else
      {
         buyTrend  = trendAdxOk && upBias   && recentCrossUp   && (rsiA <= rsiBuyPullback);
         sellTrend = trendAdxOk && downBias && recentCrossDown && (rsiA >= rsiSellPullback);
      }

      if(InpEnablePullbackTrendFollowFallback && !buyTrend && !sellTrend)
      {
         bool buyFollowFallback  = upBias   && (rsiA >= EffectiveFollowBuyRSIMin());
         bool sellFollowFallback = downBias && (rsiA <= EffectiveFollowSellRSIMax());

         if(!InpForceTrendEverywhere)
         {
            buyFollowFallback  = buyFollowFallback  && trendAdxOk;
            sellFollowFallback = sellFollowFallback && trendAdxOk;
         }

         if(buyFollowFallback)  buyTrend  = true;
         if(sellFollowFallback) sellTrend = true;
      }
   }
   else
   {
      if(InpForceTrendEverywhere)
      {
         buyTrend  = upBias   && (rsiA >= EffectiveFollowBuyRSIMin());
         sellTrend = downBias && (rsiA <= EffectiveFollowSellRSIMax());
      }
      else
      {
         buyTrend  = trendAdxOk && upBias   && (rsiA >= EffectiveFollowBuyRSIMin());
         sellTrend = trendAdxOk && downBias && (rsiA <= EffectiveFollowSellRSIMax());
      }
   }

   // ======== Range / Volatile logic (GIỮ NGUYÊN để tính env + debug) ========
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool touchLower = bandsOk && (bid <= (low0 + gBBTouchBufferPrice));
   bool touchUpper = bandsOk && (ask >= (up0  - gBBTouchBufferPrice));
   bool buyRange   = touchLower && (rsiA <= gRangeRSIBuyMax);
   bool sellRange  = touchUpper && (rsiA >= gRangeRSISellMin);

   if(InpUseKeltnerLowATRMode && bandsOk && atr0 > 0.0 && atr0 <= InpLowATRRangeThreshold)
   {
      double kMid = mid0;
      double kUp  = kMid + atr0 * MathMax(InpKeltnerATRMult, 0.1);
      double kLow = kMid - atr0 * MathMax(InpKeltnerATRMult, 0.1);
      bool buyKelt = (bid <= kLow && rsiA <= InpKeltnerRangeBuyRSIMax);
      bool sellKelt= (ask >= kUp  && rsiA >= InpKeltnerRangeSellRSIMin);
      buyRange  = buyRange  || buyKelt;
      sellRange = sellRange || sellKelt;
   }

   if(InpUseMABiasFilterForRange)
   {
      if(upBias && !downBias)   sellRange = false;
      if(downBias && !upBias)   buyRange  = false;
   }

   bool buyBreakout  = bandsOk && (ask >= (up0 + gBreakoutBufferPrice))  && (rsiA >= gMomentumRSIBuyMin);
   bool sellBreakout = bandsOk && (bid <= (low0 - gBreakoutBufferPrice)) && (rsiA <= gMomentumRSISellMax);

   bool rsiCrossUp50   = (rsiB < 50.0 && rsiA >= 50.0);
   bool rsiCrossDown50 = (rsiB > 50.0 && rsiA <= 50.0);

   bool buyRSI50  = (gUseRSI50Cross && atr0 >= gMinATRForRSI50Cross && upBias   && rsiCrossUp50);
   bool sellRSI50 = (gUseRSI50Cross && atr0 >= gMinATRForRSI50Cross && downBias && rsiCrossDown50);

   bool buyVol  = buyBreakout  || buyRSI50;
   bool sellVol = sellBreakout || sellRSI50;

   bool buySignal=false, sellSignal=false;
   string modeTag="TREND";

   // ======== v4.232: Force TREND everywhere with NO impossible RSI ========
   if(InpForceTrendEverywhere)
   {
      modeTag = "TREND";
      buySignal  = buyTrend;
      sellSignal = sellTrend;

      // Env tightening depends on TrendMode
      if(envTightNow)
      {
         if(gTrendMode == TREND_FOLLOW)
         {
            // directional RSI tightening OK (no conflict)
            if(buySignal)  buySignal  = (rsiA >= InpTrendTight_RSI_BuyMin);
            if(sellSignal) sellSignal = (rsiA <= InpTrendTight_RSI_SellMax);
         }
         else // TREND_PULLBACK
         {
            // Do NOT use RSI>=52 vs RSI<=OS. Instead require a minimal ADX to avoid dead sideways.
            if(InpTightPullback_MinADX > 0.0)
            {
               bool adxPass = (adxOk && adx0 >= InpTightPullback_MinADX);
               if(buySignal && !adxPass)  buySignal  = false;
               if(sellSignal && !adxPass) sellSignal = false;
            }
         }
      }
   }
   else
   {
      // ======== Original mode selection ========
      if(isVolatile)
      {
         modeTag = "VOLATILE";
         buySignal = buyVol;
         sellSignal = sellVol;
      }
      else if(isSideways)
      {
         modeTag = "RANGE";
         buySignal = buyRange;
         sellSignal = sellRange;
      }
      else
      {
         modeTag = "TREND";
         buySignal = buyTrend;
         sellSignal = sellTrend;
      }
   }

   //==================== DivBOS additional entry method (GIỮ NGUYÊN) ====================//
   if(InpEnableDivBOS)
   {
      bool adxPass = true;
      if(InpDivBOS_ADXFilter && adxOk && adx0 > InpDivBOS_ADXMax) adxPass = false;

      datetime bar0 = GetBarOpenTime(CalcTF(), 0);
      if(bar0 != 0 && bar0 != gLastDivBOSBar)
      {
         gLastDivBOSBar = bar0;

         if(!gDivBOS.active && adxPass)
         {
            double bh=0, bl=0; datetime born=0;
            bool bull = DivBOS_FindSetup(CalcTF(), true, InpDivBOS_LookbackBars, InpDivBOS_LeftRight,
                                         InpDivBOS_MinRSIDiff, bh, bl, born);
            bool bear = DivBOS_FindSetup(CalcTF(), false, InpDivBOS_LookbackBars, InpDivBOS_LeftRight,
                                         InpDivBOS_MinRSIDiff, bh, bl, born);

            if(bull && !bear)
            {
               if(atr0 > 0.0 && (bh - bid) >= (atr0 * InpDivBOS_MinGapATRMult))
               {
                  gDivBOS.active=true; gDivBOS.dir=+1; gDivBOS.refHigh=bh; gDivBOS.refLow=0; gDivBOS.bornBarTime=bar0;
                  Log(StringFormat("DivBOS SETUP(BULL): wait BOS break ABOVE %.2f (expire %d bars)", bh, InpDivBOS_ExpireBars));
               }
            }
            else if(bear && !bull)
            {
               if(atr0 > 0.0 && (ask - bl) >= (atr0 * InpDivBOS_MinGapATRMult))
               {
                  gDivBOS.active=true; gDivBOS.dir=-1; gDivBOS.refLow=bl; gDivBOS.refHigh=0; gDivBOS.bornBarTime=bar0;
                  Log(StringFormat("DivBOS SETUP(BEAR): wait BOS break BELOW %.2f (expire %d bars)", bl, InpDivBOS_ExpireBars));
               }
            }
         }
      }

      if(gDivBOS.active)
      {
         int bs = BarsSince(gDivBOS.bornBarTime, CalcTF());
         if(bs > InpDivBOS_ExpireBars)
         {
            Log("DivBOS EXPIRE: setup expired, reset.");
            gDivBOS.active=false; gDivBOS.dir=0; gDivBOS.refHigh=0; gDivBOS.refLow=0; gDivBOS.bornBarTime=0;
         }
      }

      if(gDivBOS.active)
      {
         bool brk = DivBOS_CheckBreak(CalcTF(), gDivBOS.dir, gDivBOS.refHigh, gDivBOS.refLow, InpDivBOS_ClosedBreak);
         if(brk)
         {
            if(gDivBOS.dir > 0) buySignal = true;
            if(gDivBOS.dir < 0) sellSignal = true;

            Log(StringFormat("DivBOS BREAK: dir=%s => inject signal (BUY=%s SELL=%s)",
                             (gDivBOS.dir>0?"BULL":"BEAR"),
                             (buySignal?"true":"false"),
                             (sellSignal?"true":"false")));

            gDivBOS.active=false; gDivBOS.dir=0; gDivBOS.refHigh=0; gDivBOS.refLow=0; gDivBOS.bornBarTime=0;
         }
      }
   }

   if(buySignal && sellSignal) return;

   if(!buySignal && !sellSignal)
   {
      if(gLogNoSignal)
      {
         string noSigReason = BuildNoSignalReason(modeTag,
                                                  rsiA, rsiB, (adxOk?adx0:0.0), atr0, adxOk,
                                                  bandsOk, up0, mid0, low0,
                                                  fastA, fastB, slowA, slowB,
                                                  upBias, downBias, biasStrong, biasDist,
                                                  isVolatile, isSideways, envTightNow,
                                                  buyTrend, sellTrend, buyRange, sellRange, buyVol, sellVol);
         LogBlockedOnce("Điều kiện kỹ thuật không đạt: " + noSigReason);
      }
      return;
   }

   if(buySignal)  AttemptEntry(ORDER_TYPE_BUY,  rsiA, atr0, modeTag, (adxOk?adx0:0.0), bandsOk, up0, mid0, low0, envTightNow);
   if(sellSignal) AttemptEntry(ORDER_TYPE_SELL, rsiA, atr0, modeTag, (adxOk?adx0:0.0), bandsOk, up0, mid0, low0, envTightNow);
}
//+------------------------------------------------------------------+

//==================== MQL5 SAFE ATR HELPER ====================//
double GetATRValue(string sym, ENUM_TIMEFRAMES tf, int period)
{
   if(hATR == INVALID_HANDLE) return 0.0;   // ← dùng global hATR
   double buf[];
   if(CopyBuffer(hATR_regime,0,0,1,buf)<=0) return 0.0;
   return buf[0];
}



/* ===================== TABLE 3 FINAL PATCH =====================
   Added modules:
   - Real ONNX ML integration
   - Sentiment bias hook
   - Real Pearson correlation
   - Partial close cleanup
   ================================================================ */

long hOnnx = INVALID_HANDLE;


// ================== SENTIMENT TỪ X - PHIÊN BẢN 100% ==================
// DUPLICATE_REMOVED 
// DUPLICATE_REMOVED 
input string InpSentimentFilePath      = "XAU_Sentiment.json";

// ================== SENTIMENT TỪ X API V2 - REAL-TIME (100% không dùng Python) ==================


input string InpXBearerToken        = "AAAAAAAAAAAAAAAAAAAAAO3T8AEAAAAA4MTwCqwNuN9qZnd%2Bs6D2XM%2FE0po%3DHJI8LDTFsts95cfxSjO0axJ1bTMUSY7TzaU82enOjOfMYKYRCm";

double GetXAUUSDSentimentScore()
{
   if(!InpUseXSentiment) return 0.50;

   string url = "https://api.twitter.com/2/tweets/search/recent"
                "?query=XAUUSD%20OR%20gold%20OR%20XAU%20lang%3Aen"
                "&tweet.fields=text"
                "&max_results=20";

   string headers = "Authorization: Bearer " + InpXBearerToken;

   char post_data[];
   char result_data[];
   string response_headers;
   int timeout_ms = 15000;

   int http_code = WebRequest("GET", url, headers, "", timeout_ms, post_data, 0, result_data, response_headers);

   if(http_code != 200)
   {
      Print(GetDisplayTimeString()+" Lỗi gọi X API: HTTP ", http_code, " - Headers: ", response_headers);
      return 0.62;
   }

   string json_response = CharArrayToString(result_data);

   Print(GetDisplayTimeString()+" X API Response (first 200 chars): ", StringSubstr(json_response, 0, 200));

   string lower_json = StringToLower(json_response);
   int bear_count = 0;

   bear_count += (StringFind(lower_json, "bear") >= 0)     ? 1 : 0;
   bear_count += (StringFind(lower_json, "bearish") >= 0)  ? 1 : 0;
   bear_count += (StringFind(lower_json, "crash") >= 0)    ? 1 : 0;
   bear_count += (StringFind(lower_json, "sell") >= 0)     ? 1 : 0;
   bear_count += (StringFind(lower_json, "down") >= 0)     ? 1 : 0;
   bear_count += (StringFind(lower_json, "negative") >= 0) ? 1 : 0;

   int total_mentions = StringFind(lower_json, "\"text\"") + 1;
   double bear_ratio = (double)bear_count / MathMax(1, total_mentions);

   double final_score = 0.50 + (bear_ratio * 0.5);
   if(final_score > 0.80) final_score = 0.80;
   if(final_score < 0.20) final_score = 0.20;

   Print(GetDisplayTimeString()+" Real-time X Sentiment: bearish_score = ", DoubleToString(final_score, 3),
         " (bear count: ", bear_count, ", mentions: ", total_mentions, ")");

   return final_score;
}



bool MLPredictBuy(double rsi,double atr,double ema_slope)
{
   if(hOnnx==INVALID_HANDLE)
      return true;

   double ml_input[3];
   ml_input[0]=rsi/100.0; ml_input[1]=atr/10.0; ml_input[2]=ema_slope/0.1;
   double output[2];

   if(!OnnxRun(hOnnx,ONNX_DEFAULT,ml_input,output))
      return true;

   double prob_buy=output[1];

   return (prob_buy>0.70);
}

double GetRealCorrelation(string sym2,int lookback=20)
{
   double price1[],price2[];

   if(CopyClose(_Symbol,PERIOD_H1,0,lookback,price1)<=0)
      return 0.0;

   if(CopyClose(sym2,PERIOD_H1,0,lookback,price2)<=0)
      return 0.0;

   double sum_xy=0,sum_x=0,sum_y=0,sum_x2=0,sum_y2=0;

   for(int i=0;i<lookback;i++)
   {
      sum_xy+=price1[i]*price2[i];
      sum_x+=price1[i];
      sum_y+=price2[i];
      sum_x2+=price1[i]*price1[i];
      sum_y2+=price2[i]*price2[i];
   }

   double n=(double)lookback;

   double corr=(n*sum_xy-sum_x*sum_y)/
      MathSqrt((n*sum_x2-sum_x*sum_x)*(n*sum_y2-sum_y*sum_y));

   return MathAbs(corr);
}

double GetCorrelation(string sym)
{
   return GetRealCorrelation(sym,20);
}

void CleanupPartialTrack(ulong ticket)
{
   for(int i=0;i<gPartialCount;i++)
   {
      if(gPartialTracks[i].ticket==ticket)
      {
         for(int j=i;j<gPartialCount-1;j++)
            gPartialTracks[j]=gPartialTracks[j+1];

         gPartialCount--;
         break;
      }
   }
}




// ===================== v4.350 FEATURE PATCH =====================
// Added missing modules from evaluation table while keeping
// existing v4.300 features (ML, sentiment, excursion, correlation, DD).

// -------- Dynamic News --------
input bool InpUseDynamicNews = true;
// DUPLICATE_REMOVED input int  InpNewsBlockBefore_Min = 30;
// DUPLICATE_REMOVED input int  InpNewsBlockAfter_Min  = 60;

bool IsHighImpactNewsSoon()
{
   MqlCalendarValue values[];
   datetime from = TimeCurrent() - 7200;
   datetime to   = TimeCurrent() + 86400;

   if(CalendarValueHistory(values, from, to) <= 0)
      return false;

   for(int i=0;i<ArraySize(values);i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;

      if(ev.importance == CALENDAR_IMPORTANCE_HIGH &&
         MathAbs(TimeCurrent() - values[i].time) <
         (InpNewsBlockBefore_Min + InpNewsBlockAfter_Min) * 60)
      {
         Print(GetDisplayTimeString()+" High impact news: ", ev.name);
         return true;
      }
   }
   return false;
}

// -------- Partial Close Track --------
struct PartialTrack
{
   ulong ticket;
   bool level1;
   bool level2;
};

PartialTrack gPartialTracks[20];
int gPartialCount = 0;

bool HasPartialClosed(ulong ticket,int level)
{
   for(int i=0;i<gPartialCount;i++)
   {
      if(gPartialTracks[i].ticket==ticket)
      {
         if(level==1) return gPartialTracks[i].level1;
         if(level==2) return gPartialTracks[i].level2;
      }
   }
   return false;
}

void MarkPartialClosed(ulong ticket,int level)
{
   for(int i=0;i<gPartialCount;i++)
   {
      if(gPartialTracks[i].ticket==ticket)
      {
         if(level==1) gPartialTracks[i].level1=true;
         if(level==2) gPartialTracks[i].level2=true;
         return;
      }
   }
}

// -------- Hedging Toggle --------
input bool InpAllowHedging = false;

// -------- Enhanced Pyramid --------
input bool   InpEnhancedPyramid = true;
input double InpPyramidProfitATRMult = 1.0;

// -------- Heiken Ashi Filter --------
input bool InpUseHeikenAshiFilter = true;
int hHeikenAshi = INVALID_HANDLE;

bool IsBullishHeikenAshi()
{
   double o[],c[];

   if(CopyBuffer(hHeikenAshi,1,1,1,o)<=0) return true;
   if(CopyBuffer(hHeikenAshi,3,1,1,c)<=0) return true;

   return (c[0] > o[0]);
}

// -------- Session Volatility Adjust --------
input bool InpSessionVolAdjust = true;
double InpAsiaADXFloorLoose = 6;

bool IsAsiaSession()
{
   MqlDateTime t;
   TimeCurrent(t);
   return (t.hour>=0 && t.hour<8);
}

void ApplySessionAdjust()
{
   if(InpSessionVolAdjust && IsAsiaSession())
      gADXSidewaysMax = InpAsiaADXFloorLoose;
}

// -------- Fibonacci TP --------
double GetFibLevel(double high,double low,double level)
{
   return low + (high-low) * level;
}

// -------- Volatility TP Adjust --------
input double InpVolTPMultFactor = 0.3;

// -------- Keltner Channel --------
input double InpKeltnerDynamicMult = 1.5;

// ===================== END PATCH =====================


// ===== v4.360 FINAL COMPLETION PATCH =====

// --- Dynamic News integration ---
bool CheckDynamicNewsBlock()
{
   if(InpUseDynamicNews && IsHighImpactNewsSoon())
   {
      Print(GetDisplayTimeString()+" Entry blocked by Dynamic News");
      return true;
   }
   return false;
}

// ===== MERGED MODULES FROM AUTO EA =====

void ApplySentimentBias(bool &buySignal,bool &sellSignal)
{
   if(!InpUseXSentiment) return;
   double bear = GetXAUUSDSentimentScore();
   if(bear > InpBearishThreshold) buySignal=false;
}

bool ApplyMLFilter(bool buySignal,double rsiA,double atr0,double ema21_1,double ema21_3)
{
   if(!InpUseMLFilter) return buySignal;
   double ema_slope=(ema21_1-ema21_3)/2.0;
   return MLPredictBuy(rsiA,atr0,ema_slope);
}

void CheckHedgingSupport()
{
   if(InpAllowHedging && AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print(GetDisplayTimeString()+" Broker does not support hedging");
}

bool CanAddPyramid(int pyramidCount,double profit,double atr0)
{
   if(!InpEnhancedPyramid) return false;
   if(pyramidCount>=InpMaxPyramidLevels) return false;
   if(profit>atr0*InpPyramidProfitATRMult) return true;
   return false;
}

bool ApplyHeikenAshiFilter(bool buySignal)
{
   if(InpUseHeikenAshiFilter && buySignal)
      return IsBullishHeikenAshi();
   return buySignal;
}

double ApplyFibTP(double tp,double swingHigh,double swingLow)
{
   if(InpUseFibTP)
      return GetFibLevel(swingHigh,swingLow,0.618);
   return tp;
}

double PredictMaxExcursion(double atr,double rsi)
{
   return atr * 2.5 * (rsi>50 ? 1.2 : 0.8);
}

double ApplyMLExcursionTP(double entry,double atr0,double rsiA,int orderType)
{
   double excursion=PredictMaxExcursion(atr0,rsiA);
   if(orderType==ORDER_TYPE_BUY)
      return entry+excursion;
   else
      return entry-excursion;
}











double CalculateTPWithML(double entry,double sl_dist,double atr0,double rsiA,int type)
{
   double tp = entry + (type==ORDER_TYPE_BUY ? sl_dist*2 : -sl_dist*2);

   // override with ML excursion prediction
   tp = ApplyMLExcursionTP(entry,atr0,rsiA,type);

   return tp;
}

void InitExcursionModel()
{
   hOnnxExcursion = OnnxCreate("xauusd_excursion.onnx",ONNX_DEFAULT);
   if(hOnnxExcursion == INVALID_HANDLE)
      Print(GetDisplayTimeString()+" ONNX Excursion model not loaded - using default ATR*2");
}

double CalculateTPWithML(int orderType,double entryRef,double sl,double slDist,double atr0,double rsiA)
{
   double targetRR = 2.0;
   double tp = (orderType == ORDER_TYPE_BUY)
               ? entryRef + (slDist * targetRR)
               : entryRef - (slDist * targetRR);

   tp = ApplyMLExcursionTP(entryRef, atr0, rsiA, orderType);

   if(MathAbs(tp - entryRef) < MathAbs(entryRef - sl) * 1.2)
      tp = (orderType == ORDER_TYPE_BUY)
           ? entryRef + MathAbs(entryRef - sl) * 1.8
           : entryRef - MathAbs(entryRef - sl) * 1.8;

   return tp;
}

void ReleaseExcursionModel()
{
   if(hOnnxExcursion != INVALID_HANDLE)
      OnnxRelease(hOnnxExcursion);
}


// ===== Added Drawdown Control Module =====
double GetCurrentDDPercent()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance<=0) return 0.0;
   return (balance-equity)/balance*100.0;
}

double AdaptiveLot(double baseLot)
{
   double dd = GetCurrentDDPercent();
   if(dd > 25) return baseLot * 0.25;
   if(dd > 15) return baseLot * 0.5;
   if(dd > 8)  return baseLot * 0.75;
   return baseLot;
}

// ===== Trading Safety Hook =====
bool IsDrawdownSafe()
{
   double dd = GetCurrentDDPercent();
   if(dd > 35)
   {
      Print(GetDisplayTimeString()+" Trading paused due to high drawdown: ",DoubleToString(dd,2),"%");
      return false;
   }
   return true;
}


// ================= INSTITUTIONAL UPGRADE MODULE =================

// ---- Liquidity Sweep Detection ----
bool IsLiquiditySweepHigh()
{
   double high0 = iHigh(_Symbol,_Period,0);
   double high1 = iHigh(_Symbol,_Period,1);
   double close0 = iClose(_Symbol,_Period,0);

   if(high0 > high1 && close0 < high1)
      return true;

   return false;
}

bool IsLiquiditySweepLow()
{
   double low0 = iLow(_Symbol,_Period,0);
   double low1 = iLow(_Symbol,_Period,1);
   double close0 = iClose(_Symbol,_Period,0);

   if(low0 < low1 && close0 > low1)
      return true;

   return false;
}

// ---- Fake Breakout Filter ----
bool IsValidBreakout()
{
   double high1 = iHigh(_Symbol,_Period,1);
   double close0 = iClose(_Symbol,_Period,0);
   double open0  = iOpen(_Symbol,_Period,0);
   double high0  = iHigh(_Symbol,_Period,0);
   double low0   = iLow(_Symbol,_Period,0);

   double body = MathAbs(close0-open0);
   double range = high0-low0;

   if(range<=0) return false;

   if(close0 > high1 && body/range > 0.4)
      return true;

   return false;
}

// ---- ATR Regime Detection ----
// ---- ATR Regime Detection ----
int GetATRRegime() 
{
   static int hATR_regime = INVALID_HANDLE;

   if(hATR_regime == INVALID_HANDLE)
      hATR_regime = iATR(_Symbol, _Period, 14);

   double buf[];
   if(CopyBuffer(hATR_regime, 0, 0, 21, buf) <= 0)
      return 1;

   double atr = buf[0];
   double atrAvg = 0.0;

   for(int i=1; i<=20; i++)
      atrAvg += buf[i];

   atrAvg /= 20.0;

   if(atr < atrAvg * 0.7) return 0;
   if(atr > atrAvg * 1.5) return 2;

   return 1;
}
// ---- Entry Permission ----
bool AllowTradeAdvanced()
{
   if(IsLiquiditySweepHigh() || IsLiquiditySweepLow())
      return false;

   if(!IsValidBreakout())
      return false;

   int regime = GetATRRegime();

   if(regime==0)
      return false;

   return true;
}

// ================= END INSTITUTIONAL UPGRADE =================

//================ ENTRY SCORE ENGINE (v4.700 upgrade) ================
int GetEntryScore(bool trendOK,bool breakoutOK,bool atrOK,bool heiken,bool sentiment,bool ml,bool correlation)
{
   int score=0;
   if(trendOK) score+=3;
   if(breakoutOK) score+=2;
   if(atrOK) score+=2;
   if(heiken) score+=1;
   if(sentiment) score+=1;
   if(ml) score+=1;
   if(correlation) score+=1;
   return score;
}

bool AllowTradeByScore(int score,int threshold=4)
{
   if(score>=threshold)
      return true;
   return false;
}

// Soft filters (do not block trade)
double AdjustLotBySoftFilters(double lot,bool sentimentBear,bool highCorrelation)
{
   if(sentimentBear)
      lot*=0.5;
   if(highCorrelation)
      lot*=0.7;
   return lot;
}
//===============================================================

//==================== v4.800 INSTITUTIONAL AI MODULES ====================//
// These modules extend analytics for XAUUSD M5 without altering core trading logic.
// They are diagnostic / scoring helpers only and can be integrated gradually.

//---------------- Liquidity Map (simple swing liquidity zones) ----------------//
double GetLiquidityDistance()
{
   double high=iHigh(_Symbol,_Period,1);
   double low =iLow(_Symbol,_Period,1);
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double distHigh=MathAbs(price-high);
   double distLow =MathAbs(price-low);
   return MathMin(distHigh,distLow);
}

//---------------- Order Block Detection (lightweight) ----------------//
bool DetectOrderBlockBull()
{
   double open1=iOpen(_Symbol,_Period,2);
   double close1=iClose(_Symbol,_Period,2);
   double open2=iOpen(_Symbol,_Period,1);
   double close2=iClose(_Symbol,_Period,1);
   if(close1<open1 && close2>open2) return true;
   return false;
}

bool DetectOrderBlockBear()
{
   double open1=iOpen(_Symbol,_Period,2);
   double close1=iClose(_Symbol,_Period,2);
   double open2=iOpen(_Symbol,_Period,1);
   double close2=iClose(_Symbol,_Period,1);
   if(close1>open1 && close2<open2) return true;
   return false;
}

//---------------- AI-style Volatility Regime ----------------//
int GetVolatilityRegimeAI()
{
   hATR_AI =iATR(_Symbol,_Period,14);
   double buf[];
   if(CopyBuffer(hATR_regime,0,0,20,buf)<=0) return 1;

   double avg=0;
   for(int i=1;i<20;i++) avg+=buf[i];
   avg/=19;

   double atr=buf[0];

   if(atr<avg*0.7) return 0;   // low volatility
   if(atr>avg*1.6) return 2;   // high volatility
   return 1;                   // normal
}

//---------------- Entry Intelligence Score ----------------//
int GetInstitutionalScore()
{
   int score=0;

   if(DetectOrderBlockBull() || DetectOrderBlockBear())
      score+=1;

   double liq=GetLiquidityDistance();
   if(liq<SymbolInfoDouble(_Symbol,SYMBOL_POINT)*200)
      score+=1;

   int regime=GetVolatilityRegimeAI();
   if(regime==1) score+=1;

   return score;
}

//---------------- Diagnostic Print ----------------//
void PrintInstitutionalDiagnostics()
{
   if(!InpDebugLogs) return;

   int regime=GetVolatilityRegimeAI();
   int score =GetInstitutionalScore();
   double liq=GetLiquidityDistance();

   Print(GetDisplayTimeString()+" [AI DIAGNOSTIC] "+
         "Regime=",regime,
         " Score=",score,
         " LiquidityDist=",DoubleToString(liq,2));
}
//==========================================================================//


//==================== v4.850 SMART NEWS RISK MODULE ====================//
// Goal: increase trade frequency safely around news for XAUUSD M5.
// Does NOT change core trading logic; only adjusts lot / soft blocking.

input bool   InpUseSmartNewsRisk      = true;   // enable smart news risk module
input int    InpHighImpactBlockMin    = 20;     // minutes block for high impact
input int    InpMediumImpactReduceMin = 30;     // window where lot is reduced
input double InpMediumNewsLotFactor   = 0.5;    // lot multiplier during medium news

// Example placeholder flags that should be set by existing news filter
bool gNewsHighImpact = false;
bool gNewsMediumImpact = false;
datetime gNewsTime = 0;

// Determine if trading should be blocked
bool SmartNewsBlock()
{
   if(!InpUseSmartNewsRisk) return false;

   if(gNewsHighImpact)
   {
      datetime now = TimeCurrent();
      if(MathAbs(now - gNewsTime) <= InpHighImpactBlockMin * 60)
      {
         if(InpDebugLogs)
            Print(GetDisplayTimeString()+" [SMART NEWS] High impact news block window active");
         return true;
      }
   }
   return false;
}

// Adjust lot size during medium impact news instead of blocking
double SmartNewsAdjustLot(double lot)
{
   if(!InpUseSmartNewsRisk) return lot;

   if(gNewsMediumImpact)
   {
      datetime now = TimeCurrent();
      if(MathAbs(now - gNewsTime) <= InpMediumImpactReduceMin * 60)
      {
         double newLot = lot * InpMediumNewsLotFactor;
         if(InpDebugLogs)
            Print(GetDisplayTimeString()+" [SMART NEWS] Medium news detected, reducing lot from ",
                  DoubleToString(lot,2)," to ",DoubleToString(newLot,2));
         return newLot;
      }
   }

   return lot;
}
//======================================================================


//==================== v5.000 INSTITUTIONAL SMART MONEY MODULE ====================//
// Designed for XAUUSD M5
// Adds:
//  - Fair Value Gap detection
//  - Real Liquidity Sweep detection (SMC style)
//  - Adaptive Entry Score
// These modules DO NOT change existing trading logic automatically.
// They provide signals and diagnostics to increase entry opportunities safely.

//---------------- FAIR VALUE GAP (FVG) DETECTION ----------------//
bool DetectBullishFVG()
{
   double high2 = iHigh(_Symbol,_Period,2);
   double low1  = iLow(_Symbol,_Period,1);

   if(low1 > high2)
      return true;

   return false;
}

bool DetectBearishFVG()
{
   double low2  = iLow(_Symbol,_Period,2);
   double high1 = iHigh(_Symbol,_Period,1);

   if(high1 < low2)
      return true;

   return false;
}

//---------------- LIQUIDITY SWEEP (SMART MONEY) ----------------//
bool DetectLiquiditySweepHigh()
{
   double prevHigh = iHigh(_Symbol,_Period,2);
   double high1    = iHigh(_Symbol,_Period,1);
   double close1   = iClose(_Symbol,_Period,1);

   if(high1 > prevHigh && close1 < prevHigh)
      return true;

   return false;
}

bool DetectLiquiditySweepLow()
{
   double prevLow = iLow(_Symbol,_Period,2);
   double low1    = iLow(_Symbol,_Period,1);
   double close1  = iClose(_Symbol,_Period,1);

   if(low1 < prevLow && close1 > prevLow)
      return true;

   return false;
}

//---------------- ADAPTIVE ENTRY SCORE ENGINE ----------------//
input int InpAdaptiveEntryThreshold = 2;

int CalculateAdaptiveEntryScore()
{
   int score = 0;

   if(DetectBullishFVG() || DetectBearishFVG())
      score++;

   if(DetectLiquiditySweepHigh() || DetectLiquiditySweepLow())
      score++;

   // volatility regime bonus
   hATR_regime = iATR(_Symbol,_Period,14);
   double atrbuf[];

   if(CopyBuffer(hATR_regime,0,0,5,atrbuf) > 0)
   {
      if(atrbuf[0] > atrbuf[1])
         score++;
   }

   return score;
}

//---------------- ENTRY SIGNAL BOOST ----------------//
bool AdaptiveEntryBoost()
{
   int score = CalculateAdaptiveEntryScore();

   if(score >= InpAdaptiveEntryThreshold)
   {
      if(InpDebugLogs)
         Print(GetDisplayTimeString()+" [SMART MONEY] Adaptive entry boost active. Score=",score);

      return true;
   }

   return false;
}

//---------------- DIAGNOSTIC ----------------//
void PrintSmartMoneyDiagnostics()
{
   if(!InpDebugLogs) return;

   bool fvgBull = DetectBullishFVG();
   bool fvgBear = DetectBearishFVG();
   bool sweepH  = DetectLiquiditySweepHigh();
   bool sweepL  = DetectLiquiditySweepLow();
   int score    = CalculateAdaptiveEntryScore();

   Print(GetDisplayTimeString()+" [SMART MONEY] FVGbull=",fvgBull,
         " FVGbear=",fvgBear,
         " SweepHigh=",sweepH,
         " SweepLow=",sweepL,
         " Score=",score);
}
//===============================================================================//

//================ AGGRESSIVE MODE OVERRIDE =================//
bool AggressiveEntryOverride(bool baseGate)
{
   if(!InpAggressiveMode) return baseGate;

   int score = CalculateAdaptiveEntryScore();

   if(score >= 2)
   {
      if(InpDebugLogs)
         Print(GetDisplayTimeString()+" [AGGRESSIVE MODE] Adaptive score override: ",score);
      return true;
   }
   return baseGate;
}
//===========================================================//


void LogNoTradeReason(string reason)
{
   if(!InpVerboseNoTradeLog) return;

   datetime now = TimeCurrent();

   if(now - gLastNoTradeLogTime < InpNoTradeLogIntervalSec)
      return;

   gLastNoTradeLogTime = now;

   Print(GetDisplayTimeString()+" [NO TRADE] ", reason);
}


void UpdateFrequencyBoostSettings()
{
   switch(InpFrequencyMode)
   {
      case FREQ_OFF:
         gFreqRSIRelax=1.0;
         gFreqATRRelax=1.0;
         gFreqVolumeRelax=1.0;
         gFreqMLRelax=1.0;
         gFreqMinEntryDelay=30;
      break;

      case FREQ_MED:
         gFreqRSIRelax=0.8;
         gFreqATRRelax=0.85;
         gFreqVolumeRelax=0.8;
         gFreqMLRelax=0.85;
         gFreqMinEntryDelay=10;
      break;

      case FREQ_HIGH:
         gFreqRSIRelax=0.6;
         gFreqATRRelax=0.7;
         gFreqVolumeRelax=0.6;
         gFreqMLRelax=0.7;
         gFreqMinEntryDelay=5;
      break;
   }
}


bool FrequencyAdaptiveGate(bool baseGate)
{
   if(InpFrequencyMode == FREQ_OFF)
      return baseGate;

   int score = CalculateAdaptiveEntryScore();

   if(InpFrequencyMode == FREQ_HIGH && score >= 2)
      return true;

   if(InpFrequencyMode == FREQ_MED && score >= 3)
      return true;

   return baseGate;
}

bool DetectLiquiditySweepMultiSwing()
{
   double high1=iHigh(_Symbol,_Period,1);
   double high2=iHigh(_Symbol,_Period,2);
   double high3=iHigh(_Symbol,_Period,3);
   double low1=iLow(_Symbol,_Period,1);
   double low2=iLow(_Symbol,_Period,2);
   double low3=iLow(_Symbol,_Period,3);

   if(high1>high2 && high1>high3) return true;
   if(low1<low2 && low1<low3) return true;

   return false;
}

int GetAIVolatilityRegime()
{
   int hATRFast = iATR(_Symbol,_Period,7);
   int hATRSlow = iATR(_Symbol,_Period,21);

   double f[], s[];
   if(CopyBuffer(hATR_regimeFast,0,0,1,f)<=0) return 1;
   if(CopyBuffer(hATR_regimeSlow,0,0,1,s)<=0) return 1;

   if(f[0] > s[0]*1.2) return 2;
   if(f[0] < s[0]*0.8) return 0;
   return 1;
}

bool IsSmartSessionActive()
{
   if(!InpEnableSmartSessionScalper) return true;

   int h = ((int)(TimeCurrent()%86400)/3600);

   if(h>=7 && h<=11) return true;
   if(h>=13 && h<=17) return true;

   return false;
}

bool ShouldLogNoTrade()
{
   static datetime last=0;
   datetime now=TimeCurrent();

   if(now-last>=InpNoTradeLogIntervalSec)
   {
      last=now;
      return true;
   }
   return false;
}


//==================== v5.700 INSTITUTIONAL LIQUIDITY ENGINE ====================

// Liquidity Heatmap (multi‑swing cluster)
bool DetectLiquidityCluster()
{
   double highs[10];
   double lows[10];

   for(int i=1;i<=10;i++)
   {
      highs[i-1]=iHigh(_Symbol,_Period,i);
      lows[i-1]=iLow(_Symbol,_Period,i);
   }

   int highCluster=0;
   int lowCluster=0;

   for(int i=0;i<9;i++)
   {
      if(MathAbs(highs[i]-highs[i+1]) < (_Point*20)) highCluster++;
      if(MathAbs(lows[i]-lows[i+1]) < (_Point*20)) lowCluster++;
   }

   if(highCluster>=3 || lowCluster>=3)
      return true;

   return false;
}

// Orderflow imbalance detection (candle body expansion)
bool DetectOrderflowImbalance()
{
   double body1=MathAbs(iClose(_Symbol,_Period,1)-iOpen(_Symbol,_Period,1));
   double body2=MathAbs(iClose(_Symbol,_Period,2)-iOpen(_Symbol,_Period,2));

   if(body1 > body2*1.5)
      return true;

   return false;
}

// Volatility clustering regime
int GetVolatilityCluster()
{
   int hATRfast=iATR(_Symbol,_Period,7);
   int hATRslow=iATR(_Symbol,_Period,21);

   double f[1],s[1];

   if(CopyBuffer(hATRfast,0,0,1,f)<=0) return 1;
   if(CopyBuffer(hATRslow,0,0,1,s)<=0) return 1;

   if(f[0] > s[0]*1.4) return 2;
   if(f[0] < s[0]*0.7) return 0;

   return 1;
}

// Smart pyramiding guard
bool AllowSmartPyramiding(int currentPositions)
{
   if(currentPositions >= 3)
      return false;

   if(GetVolatilityCluster()==0)
      return false;

   return true;
}