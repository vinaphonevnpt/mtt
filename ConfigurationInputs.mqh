#ifndef CONFIGURATION_INPUTS_MQH
#define CONFIGURATION_INPUTS_MQH

//==============================================================
// ENUM
//==============================================================
enum ENUM_PRESET_MODE { PRESET_AUTO=0, PRESET_MANUAL=1 };

enum ENUM_FREQ_MODE { FREQ_MODE_OFF=0, FREQ_MODE_MED=1, FREQ_MODE_HIGH=2 };

enum ENUM_FREQ_BOOST { FREQ_OFF=0, FREQ_MED=1, FREQ_HIGH=2 };

enum ENUM_SR_MODE { SR_OFF=0, SR_SOFT=1, SR_HARD=2 };

enum ENUM_DISPLAY_TIMEZONE
{
   TZ_SERVER=0, TZ_UTC=1, TZ_GMT=2, TZ_EST=3, TZ_CET=4, TZ_VN=5
};

//==============================================================
// 01) CÀI ĐẶT CHUNG & QUẢN LÝ VỐN
//==============================================================
input group "01) Cài đặt chung & quản lý vốn";

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5;
// Khung thời gian chính để EA phân tích tín hiệu

input long InpMagicNumber = 20260224;
// Magic number dùng để EA nhận diện lệnh

input double InpFixedLot = 0.01;
// Khối lượng giao dịch cố định

input double InpMaxRiskPercent = 2.0;
// % rủi ro tối đa cho mỗi lệnh

input bool InpBlockTradeIfRiskTooHigh = true;
// Không cho vào lệnh nếu vượt rủi ro

input bool InpOnePositionPerSymbol = false;
// Mỗi symbol chỉ giữ 1 lệnh

input int InpMaxOpenPositions = 2;
// Số lệnh tối đa

input bool InpCloseOppositePositions = false;
// Đóng lệnh ngược chiều trước khi vào lệnh mới

//==============================================================
// 02) STOP LOSS / TP / EXIT PRO
//==============================================================
input group "02) StopLoss / TakeProfit / Exit nâng cao";

input bool   InpUseRRStops = true;
// Dùng SL/TP theo RR

input double InpRRRatio = 1.5;
// Tỷ lệ Risk:Reward

input bool   InpUseATRStop = true;
// Dùng ATR để tính SL

input double InpATRMultiplierSL = 1.5;
// Hệ số ATR cho StopLoss

input bool   InpUseATRProfitLock = true;
// Khóa lợi nhuận theo ATR

input bool   InpUseProfitDropExit = true;
// Thoát khi lợi nhuận giảm mạnh

input int    InpSpreadBufferPips = 15;
// Buffer SL theo spread

input bool   InpEnableBreakEven = true;
// Bật hòa vốn

input double InpBEThreshold = 0.50;
// % TP để kích hoạt BE

input double InpBE_RR_Trigger = 1.0;
// RR để kích hoạt BE

input double InpBE_OffsetPrice = 0.35;
// Offset khi BE

input bool   InpUseTrailingStop = true;
// Bật trailing stop

input double InpTrailStartPrice = 3.2;
// Bắt đầu trailing

input double InpTrailStepPrice = 1.2;
// Bước trailing

input bool   InpFixStops = false;
// Dùng SL/TP cố định

input double InpStopLossStepPrice = 7.5;
// Khoảng SL cố định

input double InpTakeProfitStepPrice = 4.5;
// Khoảng TP cố định


//==============================================================
// 03) TẦN SUẤT VÀO LỆNH
//==============================================================
input group "03) Tần suất vào lệnh";

input bool InpTradeOnNewBar = true;
// Chỉ trade khi có nến mới

input bool InpUseClosedBarSignals = true;
// Dùng nến đóng

input int InpMinSecondsBetweenEntries = 30;
// Delay giữa entry

input int InpMinMinutesBetweenPositions = 1;
// Delay giữa position

input bool InpAggressiveMode = false;
// Mode vào lệnh nhanh

input bool InpHighFrequencyMode = true;
// Mode tần suất cao

// Mức độ tăng tần suất giao dịch (OFF = an toàn, MED = cân bằng, HIGH = aggressive)
input ENUM_FREQ_BOOST InpFrequencyMode = FREQ_HIGH;
//==============================================================
// 04) SPREAD & SENTIMENT
//==============================================================
input group "04) Spread & Sentiment";

input bool   InpUseMaxSpread = true;
// Bật filter spread

input int    InpMaxSpreadPoints = 250;
// Spread tối đa

input int    InpSlippagePoints = 50;
// Slippage tối đa

input bool   InpUseXSentiment = false;
// Bật sentiment

input double InpBearishThreshold = -0.3;
// Ngưỡng bearish

input string InpSentimentFilePath = "sentiment.csv";
// File sentiment


//==============================================================
// 05) TREND & MTF
//==============================================================
input group "05) Trend & MTF";

input bool            InpRequireMTFTrendAlign = true;
// Yêu cầu MTF đồng thuận

input ENUM_TIMEFRAMES InpTrendTF1 = PERIOD_M15;
// TF trung

input ENUM_TIMEFRAMES InpTrendTF2 = PERIOD_H1;
// TF lớn

input bool            InpUseEMA21_50Filter = true;
// Filter EMA21/50

input bool            InpAutoTrendModeByTF = true;
// Auto trend/pullback

input bool            InpUseEnhancedTrendDirection = true;
// Trend nâng cao

input double          InpTrendSlopeMinPrice = 0.07;
// Độ dốc EMA

input bool            InpUseAntiChaseFilter = true;
// Anti chase

input bool            InpUseAntiExhaustionFilter = true;
// Anti exhaustion

input bool            InpUseHybridSignalATR_SL = true;
// Hybrid SL

input bool            InpUseMinSLDistanceFloor = true;
// SL tối thiểu

input bool            InpUseTickVolumeBreakoutFilter = true;
// Volume breakout

input bool            InpUseThreeLayerMTF = true;
// MTF 3 lớp

input int             InpMTF_PullbackLookbackBars = 8;
// Lookback pullback


//==============================================================
// 06) INDICATOR CORE
//==============================================================
input group "06) Indicator Core";

input int InpRSIPeriod = 14;
// Chu kỳ RSI

input int InpATRPeriod = 14;
// Chu kỳ ATR

input int InpADXPeriod = 14;
// Chu kỳ ADX


//==============================================================
// 07) SIGNAL PRO
//==============================================================
input group "07) Signal PRO";

input bool         InpUsePriceActionConfirm = true;
// Price Action confirm

input bool         InpUseSRConfirm = true;
// Support Resistance confirm

input ENUM_SR_MODE InpSRMode = SR_SOFT;
// Mode SR

input bool         InpUseStochFilter = true;
// Stochastic filter

input double       InpTF_StochBuy_MinK = 28.0;
// Min K BUY

input double       InpTF_StochSell_MaxK = 72.0;
// Max K SELL


//==============================================================
// 08) ADVANCED FILTER
//==============================================================
input group "08) Advanced Filters";

input bool   InpUseRSI_OBOS_Filter = true;
// RSI OB/OS filter

input bool   InpUseADXFilter = true;
// ADX filter

input bool   InpUseHeikenAshiConfirm = false;
// Heiken Ashi confirm

input bool   InpUseKeltnerLowATRMode = true;
// Keltner mode

input double InpKeltnerATRMult = 1.25;
// ATR Keltner

input double InpKeltnerRangeBuyRSIMax = 42.0;
// RSI BUY range

input double InpKeltnerRangeSellRSIMin = 58.0;
// RSI SELL range
input double InpADXSidewaysMax = 19.0;
// Ngưỡng ADX tối đa để xác định thị trường sideway (ADX thấp → thị trường yếu, dễ đảo chiều)

//==============================================================
// 09) SMART MONEY
//==============================================================
input group "09) Smart Money";

input bool InpEnableDivBOS = true;
// Break of structure

input bool InpEnableLiquiditySweep = true;
// Liquidity sweep


//==============================================================
// 10) SESSION
//==============================================================
input group "10) Session";

input bool InpUseTimeFilter = false;
// Time filter

input int InpTradeStartHour = 7;
// Start hour

input int InpTradeEndHour = 22;
// End hour

input bool InpBlockBeforeSessions = true;
// Block trước session

input int InpBlockBeforeEU_Min = 30;
// Block EU

input int InpBlockBeforeUS_Min = 30;
// Block US

input bool InpEnableSessionAdaptiveThresholds = true;
// Adaptive theo session

input double InpAsiaSessionLoosenFactor = 0.92;
// Asia loosen

input double InpLondonNYSessionTightFactor = 1.05;
// EU/US tighten

//==============================================================
// 12) Bộ lọc tin tức nâng cao (Manual + Dynamic)
//==============================================================
input group "12) Bộ lọc tin tức nâng cao";

input bool InpBlockAroundNews = true;
// Bật chặn giao dịch quanh thời điểm tin tức mạnh

input string InpHighImpactNewsTimes = "";
// Danh sách thời gian tin mạnh (format: "HH:MM;HH:MM")
// Ví dụ: "13:30;19:00"

input int InpNewsBlockBefore_Min = 30;
// Số phút chặn trước thời điểm tin

input int InpNewsBlockAfter_Min = 60;
// Số phút chặn sau thời điểm tin
//==============================================================
// 14) SCALPING PRO
//==============================================================
input group "14) Scalping Pro";

input bool InpEnableScalpingProLayer = true;
// Layer scalping


//==============================================================
// 15) PYRAMIDING
//==============================================================
input group "15) Pyramiding";

input bool   InpEnablePyramidingSafe = true;
// Pyramiding an toàn

input int    InpPyramidMaxAddsPerTrend = 1;
// Max add
//==============================================================
// 16) Volatility TP (ML Adaptive TP)
//==============================================================
input group "16) Điều chỉnh TP theo Volatility (ML)";

input bool InpUseVolatilityTPAdjust = true;
// Bật/tắt điều chỉnh TakeProfit theo biến động ATR + ML

input double InpVolatilityTPFactor = 0.35;
// Hệ số nhân ATR để mở rộng hoặc thu hẹp TP theo volatility

//==============================================================
// 17) PROFIT PROTECTION
//==============================================================
input group "17) Profit Protection";

input bool InpUseFibTP = true;
// Fibonacci TP


//==============================================================
// 18) ML + NEWS + DD + PARTIAL
//==============================================================
input group "18) ML + News + DD";

input bool   InpUseProbabilisticMLFilter = true;
input double InpMLScoreThreshold_Buy = 0.58;
input double InpMLScoreThreshold_Sell = 0.58;
input double InpMLTrendWeight = 0.24;
input double InpMLMomentumWeight = 0.18;
input double InpMLVolWeight = 0.12;
input double InpMLMTFWeight = 0.18;
input double InpMLPAWeight = 0.14;
input bool   InpUseIchimokuBiasFilter = false;

input string InpDynamicNewsCurrencies = "USD";
input int    InpDynamicNewsLookahead_Min = 120;
input string InpDynamicNewsKeywords = "CPI;NFP;FOMC";

input bool   InpEnableBacktestCSVExport = false;
input string InpBacktestCSVFileName = "backtest_log.csv";

// Drawdown
input bool   InpEnableDrawdownGuard = true;
input double InpDrawdownWarnPercent = 8.0;
input double InpDrawdownPausePercent = 12.0;
input double InpDrawdownLotReducePercent = 50.0;

// Partial
input bool   InpEnablePartialClose = true;
input double InpPartialClose_RR = 1.0;
input double InpPartialClose_Fraction = 0.5;
input double InpPartialClose_MinLot = 0.01;


//==============================================================
// LOGGING
//==============================================================
input group "Logging";

input ENUM_DISPLAY_TIMEZONE InpDisplayTimezone = TZ_SERVER;
input bool InpVerboseLogs = true;
input int  InpUSSessionStartHour = 19;
#endif