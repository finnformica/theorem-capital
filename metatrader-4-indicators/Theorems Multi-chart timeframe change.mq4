//+------------------------------------------------------------------+
//|        Theorems Multi-chart timeframe sync FAST GV.mq4           |
//|   Attach to every chart you want synced.                         |
//|   Any chart can become the master.                               |
//|   Uses GlobalVariables + millisecond timer for faster sync.      |
//+------------------------------------------------------------------+
#property strict

input int  PollMilliseconds   = 200;   // faster than 1-second timer
input int  SyncCooldownMs     = 600;   // lock after sync to reduce bounce
input bool SyncOnlySameSymbol = false; // true = only sync charts of same symbol

string GV_TF_VALUE = "THEOREM_TF_SYNC_VALUE";
string GV_TF_LOCK  = "THEOREM_TF_SYNC_LOCK";

long g_chartIds[];
int  g_chartPeriods[];

int g_pollMs     = 200;
int g_cooldownMs = 600;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_pollMs     = PollMilliseconds;
   g_cooldownMs = SyncCooldownMs;

   if(g_pollMs < 50)
      g_pollMs = 50;

   if(g_cooldownMs < 100)
      g_cooldownMs = 100;

   RefreshChartList();
   EnsureGlobalsExist();

   // Seed the shared timeframe if empty
   if(GlobalVariableGet(GV_TF_VALUE) <= 0)
      GlobalVariableSet(GV_TF_VALUE, ChartPeriod(0));

   EventSetMillisecondTimer(g_pollMs);

   Print("Fast timeframe sync initialized on chart ", ChartID(),
         " (", Symbol(), ", ", TimeframeToString(ChartPeriod(0)), ")");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // No tick logic needed
}

//+------------------------------------------------------------------+
//| Timer                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   bool structureChanged = RebuildChartListIfNeeded();

   if(IsSyncLocked())
   {
      RefreshTrackedPeriodsOnly();
      return;
   }

   long changedChartId = -1;
   int  changedTf      = 0;

   // Step 1: detect a manual timeframe change
   if(DetectManualChartChange(changedChartId, changedTf))
   {
      GlobalVariableSet(GV_TF_LOCK, TimeLocal() + (double)g_cooldownMs / 1000.0);
      GlobalVariableSet(GV_TF_VALUE, changedTf);

      ApplySharedTimeframe(changedChartId, changedTf);
      RefreshChartList();
      return;
   }

   // Step 2: if a chart was reopened/reinitialized, reconcile to shared tf
   int sharedTf = (int)GlobalVariableGet(GV_TF_VALUE);
   if(sharedTf > 0 && (structureChanged || NeedsApplySharedTf(sharedTf)))
   {
      GlobalVariableSet(GV_TF_LOCK, TimeLocal() + (double)g_cooldownMs / 1000.0);
      ApplySharedTimeframe(-1, sharedTf);
      RefreshChartList();
      return;
   }

   RefreshTrackedPeriodsOnly();
}

//+------------------------------------------------------------------+
//| Ensure global variables exist                                    |
//+------------------------------------------------------------------+
void EnsureGlobalsExist()
{
   if(!GlobalVariableCheck(GV_TF_VALUE))
      GlobalVariableSet(GV_TF_VALUE, 0);

   if(!GlobalVariableCheck(GV_TF_LOCK))
      GlobalVariableSet(GV_TF_LOCK, 0);
}

//+------------------------------------------------------------------+
//| Rebuild chart list only when needed                              |
//+------------------------------------------------------------------+
bool RebuildChartListIfNeeded()
{
   int trackedCount = ArraySize(g_chartIds);

   int liveCount = 0;
   long cid = ChartFirst();
   while(cid >= 0)
   {
      liveCount++;
      cid = ChartNext(cid);
   }

   if(liveCount != trackedCount)
   {
      RefreshChartList();
      return(true);
   }

   cid = ChartFirst();
   while(cid >= 0)
   {
      if(FindChartIndex(cid) < 0)
      {
         RefreshChartList();
         return(true);
      }
      cid = ChartNext(cid);
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Detect a chart whose timeframe changed                           |
//+------------------------------------------------------------------+
bool DetectManualChartChange(long &changedChartId, int &changedTf)
{
   changedChartId = -1;
   changedTf      = 0;

   for(int i = 0; i < ArraySize(g_chartIds); i++)
   {
      long cid = g_chartIds[i];

      int currentTf = ChartPeriod(cid);
      if(currentTf == 0) // chart no longer valid
         continue;

      if(currentTf != g_chartPeriods[i])
      {
         changedChartId = cid;
         changedTf      = currentTf;
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Apply shared timeframe                                           |
//+------------------------------------------------------------------+
void ApplySharedTimeframe(long masterChartId, int newTf)
{
   int updated = 0;
   int failed  = 0;
   string masterSymbol = "";

   if(masterChartId > 0)
      masterSymbol = ChartSymbol(masterChartId);

   for(int i = 0; i < ArraySize(g_chartIds); i++)
   {
      long cid = g_chartIds[i];

      string sym = ChartSymbol(cid);
      if(sym == "")
         continue;

      if(SyncOnlySameSymbol && masterSymbol != "" && sym != masterSymbol)
      {
         g_chartPeriods[i] = ChartPeriod(cid);
         continue;
      }

      int currentTf = ChartPeriod(cid);
      if(currentTf == 0)
         continue;

      if(currentTf != newTf)
      {
         // Preserve the chart's own symbol; only change timeframe
         if(ChartSetSymbolPeriod(cid, sym, newTf))
            updated++;
         else
         {
            failed++;
            Print("Failed to sync chart ID ", cid,
                  " (", sym, ") to ", TimeframeToString(newTf));
         }
      }

      g_chartPeriods[i] = newTf;
   }

   Print("Applied timeframe ", TimeframeToString(newTf),
         ". Updated ", updated, " chart(s), failed ", failed, ".");
}

//+------------------------------------------------------------------+
//| Check whether charts still need shared timeframe                 |
//+------------------------------------------------------------------+
bool NeedsApplySharedTf(int sharedTf)
{
   for(int i = 0; i < ArraySize(g_chartIds); i++)
   {
      long cid = g_chartIds[i];
      int tf = ChartPeriod(cid);

      if(tf == 0)
         continue;

      if(tf != sharedTf)
         return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Refresh full tracking                                            |
//+------------------------------------------------------------------+
void RefreshChartList()
{
   ArrayResize(g_chartIds, 0);
   ArrayResize(g_chartPeriods, 0);

   long cid = ChartFirst();
   int n = 0;

   while(cid >= 0)
   {
      int tf = ChartPeriod(cid);
      if(tf > 0)
      {
         ArrayResize(g_chartIds, n + 1);
         ArrayResize(g_chartPeriods, n + 1);

         g_chartIds[n]     = cid;
         g_chartPeriods[n] = tf;
         n++;
      }

      cid = ChartNext(cid);
   }
}

//+------------------------------------------------------------------+
//| Refresh stored periods only                                      |
//+------------------------------------------------------------------+
void RefreshTrackedPeriodsOnly()
{
   for(int i = 0; i < ArraySize(g_chartIds); i++)
   {
      int tf = ChartPeriod(g_chartIds[i]);
      if(tf > 0)
         g_chartPeriods[i] = tf;
   }
}

//+------------------------------------------------------------------+
//| Find chart index                                                 |
//+------------------------------------------------------------------+
int FindChartIndex(long chartId)
{
   for(int i = 0; i < ArraySize(g_chartIds); i++)
   {
      if(g_chartIds[i] == chartId)
         return(i);
   }
   return(-1);
}

//+------------------------------------------------------------------+
//| Lock check                                                       |
//+------------------------------------------------------------------+
bool IsSyncLocked()
{
   double lockUntil = GlobalVariableGet(GV_TF_LOCK);
   if(lockUntil <= 0)
      return(false);

   return(TimeLocal() < (datetime)lockUntil);
}

//+------------------------------------------------------------------+
//| Timeframe to text                                                |
//+------------------------------------------------------------------+
string TimeframeToString(int tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return("M1");
      case PERIOD_M5:   return("M5");
      case PERIOD_M15:  return("M15");
      case PERIOD_M30:  return("M30");
      case PERIOD_H1:   return("H1");
      case PERIOD_H4:   return("H4");
      case PERIOD_D1:   return("D1");
      case PERIOD_W1:   return("W1");
      case PERIOD_MN1:  return("MN1");

      case PERIOD_M2:   return("M2");
      case PERIOD_M3:   return("M3");
      case PERIOD_M4:   return("M4");
      case PERIOD_M6:   return("M6");
      case PERIOD_M10:  return("M10");
      case PERIOD_M12:  return("M12");
      case PERIOD_M20:  return("M20");
      case PERIOD_H2:   return("H2");
      case PERIOD_H3:   return("H3");
      case PERIOD_H6:   return("H6");
      case PERIOD_H8:   return("H8");
      case PERIOD_H12:  return("H12");
   }

   return(IntegerToString(tf));
}
//+------------------------------------------------------------------+