#ifndef __LOGGING_AND_TIME_UTILS_MQH__
#define __LOGGING_AND_TIME_UTILS_MQH__

//==============================================================
// LoggingAndTimeUtils.mqh (SMART - PRODUCTION READY)
// - Anti-spam logging
// - Rate limit theo key
// - Log once / state change
// - Time helpers chuẩn MQL5
//==============================================================

#include "ConfigurationInputs.mqh"

//==============================================================
// GLOBAL STORAGE (SIMPLE ARRAY BASED)
//==============================================================
#define MAX_LOG_KEYS 200

string   gLogKeys[MAX_LOG_KEYS];
datetime gLogTimes[MAX_LOG_KEYS];
bool     gLogStates[MAX_LOG_KEYS];
int      gLogCount = 0;

//==============================================================
// FIND INDEX BY KEY
//==============================================================
int FindLogIndex(string key)
{
   for(int i=0;i<gLogCount;i++)
   {
      if(gLogKeys[i] == key)
         return i;
   }

   if(gLogCount < MAX_LOG_KEYS)
   {
      gLogKeys[gLogCount]  = key;
      gLogTimes[gLogCount] = 0;
      gLogStates[gLogCount]= false;
      gLogCount++;
      return gLogCount-1;
   }

   return -1;
}

//==============================================================
// TIME HELPERS (CENTRALIZED)
//==============================================================
int GetHourNow()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   return t.hour;
}

int GetMinuteNow()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   return t.min;
}

//==============================================================
// BASIC LOG (CONTROLLED)
//==============================================================
void Log(string msg)
{
   if(!InpVerboseLogs)
      return;

   Print(msg);
}

//==============================================================
// LOG SMART (RATE LIMIT)
//==============================================================
void LogSmart(string key, string msg, int cooldownSec=30)
{
   if(!InpVerboseLogs)
      return;

   int idx = FindLogIndex(key);
   if(idx < 0) return;

   datetime now = TimeCurrent();

   if(now - gLogTimes[idx] >= cooldownSec)
   {
      Print(msg);
      gLogTimes[idx] = now;
   }
}

//==============================================================
// LOG ONCE
//==============================================================
void LogOnce(string key, string msg)
{
   if(!InpVerboseLogs)
      return;

   int idx = FindLogIndex(key);
   if(idx < 0) return;

   if(!gLogStates[idx])
   {
      Print(msg);
      gLogStates[idx] = true;
   }
}

//==============================================================
// RESET LOG STATE (WHEN CONDITION END)
//==============================================================
void ResetLogState(string key)
{
   int idx = FindLogIndex(key);
   if(idx < 0) return;

   gLogStates[idx] = false;
}

//==============================================================
// LOG STATE CHANGE
//==============================================================
void LogStateChange(string key, bool state, string msgTrue, string msgFalse="")
{
   if(!InpVerboseLogs)
      return;

   int idx = FindLogIndex(key);
   if(idx < 0) return;

   if(gLogStates[idx] != state)
   {
      gLogStates[idx] = state;

      if(state)
         Print(msgTrue);
      else if(msgFalse != "")
         Print(msgFalse);
   }
}

//==============================================================
// LOG BLOCK (ANTI-SPAM)
//==============================================================
void LogBlockedOnce(string reason)
{
   string key = "BLOCK_" + reason;
   LogOnce(key, "[BLOCK] " + reason);
}

//==============================================================
// LOG TAG (MODULE PREFIX)
//==============================================================
void LogTag(string tag, string msg)
{
   if(!InpVerboseLogs)
      return;

   Print("[" + tag + "] " + msg);
}

//==============================================================
// TIME STRING DISPLAY
//==============================================================
string GetDisplayTimeString()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);

   return StringFormat("%02d:%02d:%02d", t.hour, t.min, t.sec);
}

//==============================================================
// BLOCK BEFORE SESSION (USED BY SESSION MODULE)
//==============================================================
bool IsBlockedBeforeSession(string &reason)
{
   if(!InpBlockBeforeSessions)
      return false;

   int nowMin = GetHourNow()*60 + GetMinuteNow();

   int euStart = InpTradeStartHour * 60;
   int usStart = InpUSSessionStartHour * 60;

   if(MathAbs(nowMin - euStart) <= InpBlockBeforeEU_Min)
   {
      reason = "Chặn trước phiên EU";
      return true;
   }

   if(MathAbs(nowMin - usStart) <= InpBlockBeforeUS_Min)
   {
      reason = "Chặn trước phiên US";
      return true;
   }

   return false;
}
//==============================================================
// ENTRY TIME TRACKING
//==============================================================
datetime gLastEntryTime = 0;

void MarkEntryTime()
{
   gLastEntryTime = TimeCurrent();
}

datetime GetLastEntryTime()
{
   return gLastEntryTime;
}
#endif