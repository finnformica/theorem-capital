#property strict
#property indicator_chart_window

//====================================================
// Theorem SMT Divergences - Unified Event MT4
//
// Strict consecutive shared-event SMT
// - Base pivots are built once
// - All enabled comparison symbols are tested against the SAME base pivot events
// - A symbol is only compared when it matched BOTH consecutive base events
// - Prevents old symbol pivots from leaking into newer base events
//
// Optimizations kept:
// 1) Runs heavy logic only on new bar
// 2) Does not delete/recreate all objects every tick
// 3) Caches external symbol OHLC/time arrays once per update
//
// Added:
// - Inversion toggle per comparison symbol
//====================================================

//----------------------------
// Inputs
//----------------------------
input int      InpPivotLookback           = 3;

input bool     InpUseSymbol1              = true;
input string   InpSymbol1                 = "US500";
input bool     InpInvertSymbol1           = false;

input bool     InpUseSymbol2              = true;
input string   InpSymbol2                 = "US30";
input bool     InpInvertSymbol2           = false;

input bool     InpUseSymbol3              = false;
input string   InpSymbol3                 = "NAS100";
input bool     InpInvertSymbol3           = false;

input bool     InpUseSymbol4              = false;
input string   InpSymbol4                 = "GER40";
input bool     InpInvertSymbol4           = false;

input bool     InpEnforceM15              = false;
input int      InpMaxPivotTimeGapBars     = 2;

// Lower = lighter load
input int      InpHistoryBarsToProcess    = 500;

input color    InpSwingHighColor          = clrRed;
input color    InpSwingLowColor           = clrDodgerBlue;
input int      InpLineWidth               = 2;
input ENUM_LINE_STYLE InpLineStyle        = STYLE_SOLID;

input bool     InpDrawLines               = true;
input bool     InpDrawLabels              = true;
input bool     InpShowDashboard           = true;
input bool     InpEnableAlerts            = false;
input bool     InpAlertOncePerBar         = true;

input string   InpObjectPrefix            = "THEOREM_SMT_";

//----------------------------
// Globals
//----------------------------
datetime g_lastProcessedBarTime = 0;
datetime g_lastAlertBarHigh     = 0;
datetime g_lastAlertBarLow      = 0;
bool     g_firstBuildDone       = false;

int g_baseHighCount = 0;
int g_baseLowCount  = 0;

int g_s1High = 0, g_s1Low = 0;
int g_s2High = 0, g_s2Low = 0;
int g_s3High = 0, g_s3Low = 0;
int g_s4High = 0, g_s4Low = 0;

//====================================================
// Helpers
//====================================================
string TfToStr(int tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return "M1";
      case PERIOD_M5:   return "M5";
      case PERIOD_M15:  return "M15";
      case PERIOD_M30:  return "M30";
      case PERIOD_H1:   return "H1";
      case PERIOD_H4:   return "H4";
      case PERIOD_D1:   return "D1";
      case PERIOD_W1:   return "W1";
      case PERIOD_MN1:  return "MN1";
   }
   return "TF";
}

bool SymbolReady(string sym)
{
   if(sym == "" || sym == NULL)
      return false;

   if(!SymbolSelect(sym, true))
      return false;

   if(iBars(sym, Period()) < (InpPivotLookback * 2 + 20))
      return false;

   return true;
}

bool IsPivotHighArr(const double &arr[], int i, int L, int barsCount)
{
   if(i - L < 0 || i + L >= barsCount)
      return false;

   double p = arr[i];
   for(int k = 1; k <= L; k++)
   {
      if(arr[i - k] >= p) return false;
      if(arr[i + k] >  p) return false;
   }
   return true;
}

bool IsPivotLowArr(const double &arr[], int i, int L, int barsCount)
{
   if(i - L < 0 || i + L >= barsCount)
      return false;

   double p = arr[i];
   for(int k = 1; k <= L; k++)
   {
      if(arr[i - k] <= p) return false;
      if(arr[i + k] <  p) return false;
   }
   return true;
}

bool CacheSymbolData(string sym, int tf, int barsToCopy,
                     datetime &outTime[],
                     double &outHigh[],
                     double &outLow[],
                     int &outCount)
{
   outCount = 0;

   if(!SymbolReady(sym))
      return false;

   ArrayResize(outTime, barsToCopy);
   ArrayResize(outHigh, barsToCopy);
   ArrayResize(outLow,  barsToCopy);

   ArraySetAsSeries(outTime, true);
   ArraySetAsSeries(outHigh, true);
   ArraySetAsSeries(outLow,  true);

   int ct = CopyTime(sym, tf, 0, barsToCopy, outTime);
   int ch = CopyHigh(sym, tf, 0, barsToCopy, outHigh);
   int cl = CopyLow(sym, tf, 0, barsToCopy, outLow);

   if(ct <= 0 || ch <= 0 || cl <= 0)
      return false;

   outCount = MathMin(ct, MathMin(ch, cl));
   return (outCount > (InpPivotLookback * 2 + 10));
}

bool FindNearestCachedPivotShift(const datetime &baseTime[],
                                 const datetime &symTime[],
                                 const double &symPriceArr[],
                                 int baseShift,
                                 int symBarsCount,
                                 bool isHigh,
                                 int L,
                                 int maxGapBars,
                                 int &outShift,
                                 double &outPrice)
{
   outShift = -1;
   outPrice = 0.0;

   int bestShift = -1;
   int bestDist  = 999999;
   int secLimit  = (maxGapBars + 1) * PeriodSeconds();

   for(int d = -maxGapBars; d <= maxGapBars; d++)
   {
      int s = baseShift + d;
      if(s < 0 || s >= symBarsCount)
         continue;

      bool isPivot = false;
      if(isHigh) isPivot = IsPivotHighArr(symPriceArr, s, L, symBarsCount);
      else       isPivot = IsPivotLowArr(symPriceArr,  s, L, symBarsCount);

      if(!isPivot)
         continue;

      int timeDiff = MathAbs((int)(baseTime[baseShift] - symTime[s]));
      if(timeDiff > secLimit)
         continue;

      int dist = MathAbs(d);
      if(dist < bestDist)
      {
         bestDist  = dist;
         bestShift = s;
      }
   }

   if(bestShift < 0)
      return false;

   outShift = bestShift;
   outPrice = symPriceArr[bestShift];
   return true;
}

void DrawTrendLineIfMissing(string name, datetime t1, double p1, datetime t2, double p2, color clr)
{
   if(!InpDrawLines)
      return;

   if(ObjectFind(name) >= 0)
      return;

   if(!ObjectCreate(name, OBJ_TREND, 0, t1, p1, t2, p2))
      return;

   ObjectSet(name, OBJPROP_COLOR, clr);
   ObjectSet(name, OBJPROP_WIDTH, InpLineWidth);
   ObjectSet(name, OBJPROP_STYLE, InpLineStyle);
   ObjectSet(name, OBJPROP_RAY, false);
   ObjectSet(name, OBJPROP_BACK, false);
}

void DrawTextLabelIfMissing(string name, datetime t, double p, string txt, color clr, bool above)
{
   if(!InpDrawLabels)
      return;

   double range = WindowPriceMax() - WindowPriceMin();
   if(range <= 0) range = 100 * Point;

   double offset = range * 0.01;
   double finalPrice = above ? (p + offset) : (p - offset);

   if(ObjectFind(name) < 0)
   {
      if(!ObjectCreate(name, OBJ_TEXT, 0, t, finalPrice))
         return;
   }

   ObjectMove(name, 0, t, finalPrice);
   ObjectSetText(name, txt, 8, "Arial", clr);
}

void FireAlert(bool isHigh, string symbolsText, datetime barTime)
{
   if(!InpEnableAlerts)
      return;

   if(InpAlertOncePerBar)
   {
      if(isHigh)
      {
         if(g_lastAlertBarHigh == barTime) return;
         g_lastAlertBarHigh = barTime;
      }
      else
      {
         if(g_lastAlertBarLow == barTime) return;
         g_lastAlertBarLow = barTime;
      }
   }

   string side = isHigh ? "Swing High SMT" : "Swing Low SMT";
   Alert(Symbol(), " ", TfToStr(Period()), " ", side, " vs ", symbolsText);
}

void CleanupAllIndicatorObjects()
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, InpObjectPrefix, 0) == 0)
         ObjectDelete(name);
   }
}

void UpdateDashboard()
{
   string name = InpObjectPrefix + "DASH";

   if(!InpShowDashboard)
   {
      if(ObjectFind(name) >= 0)
         ObjectDelete(name);
      return;
   }

   double p1h = (g_baseHighCount > 0 ? 100.0 * g_s1High / g_baseHighCount : 0.0);
   double p1l = (g_baseLowCount  > 0 ? 100.0 * g_s1Low  / g_baseLowCount  : 0.0);
   double p2h = (g_baseHighCount > 0 ? 100.0 * g_s2High / g_baseHighCount : 0.0);
   double p2l = (g_baseLowCount  > 0 ? 100.0 * g_s2Low  / g_baseLowCount  : 0.0);
   double p3h = (g_baseHighCount > 0 ? 100.0 * g_s3High / g_baseHighCount : 0.0);
   double p3l = (g_baseLowCount  > 0 ? 100.0 * g_s3Low  / g_baseLowCount  : 0.0);
   double p4h = (g_baseHighCount > 0 ? 100.0 * g_s4High / g_baseHighCount : 0.0);
   double p4l = (g_baseLowCount  > 0 ? 100.0 * g_s4Low  / g_baseLowCount  : 0.0);

   string s1Tag = InpUseSymbol1 ? (InpInvertSymbol1 ? " (Inv)" : "") : "";
   string s2Tag = InpUseSymbol2 ? (InpInvertSymbol2 ? " (Inv)" : "") : "";
   string s3Tag = InpUseSymbol3 ? (InpInvertSymbol3 ? " (Inv)" : "") : "";
   string s4Tag = InpUseSymbol4 ? (InpInvertSymbol4 ? " (Inv)" : "") : "";

   string txt =
      "THEOREM SMT DASHBOARD\n" +
      "Chart: " + Symbol() + " [" + TfToStr(Period()) + "]\n" +
      "Base Highs: " + IntegerToString(g_baseHighCount) + "\n" +
      "Base Lows : " + IntegerToString(g_baseLowCount) + "\n\n" +
      InpSymbol1 + s1Tag + " H: " + IntegerToString(g_s1High) + " (" + DoubleToString(p1h,1) + "%)  L: " + IntegerToString(g_s1Low) + " (" + DoubleToString(p1l,1) + "%)\n" +
      InpSymbol2 + s2Tag + " H: " + IntegerToString(g_s2High) + " (" + DoubleToString(p2h,1) + "%)  L: " + IntegerToString(g_s2Low) + " (" + DoubleToString(p2l,1) + "%)\n" +
      InpSymbol3 + s3Tag + " H: " + IntegerToString(g_s3High) + " (" + DoubleToString(p3h,1) + "%)  L: " + IntegerToString(g_s3Low) + " (" + DoubleToString(p3l,1) + "%)\n" +
      InpSymbol4 + s4Tag + " H: " + IntegerToString(g_s4High) + " (" + DoubleToString(p4h,1) + "%)  L: " + IntegerToString(g_s4Low) + " (" + DoubleToString(p4l,1) + "%)\n";

   if(ObjectFind(name) < 0)
      ObjectCreate(name, OBJ_LABEL, 0, 0, 0);

   ObjectSet(name, OBJPROP_CORNER, 1);
   ObjectSet(name, OBJPROP_XDISTANCE, 10);
   ObjectSet(name, OBJPROP_YDISTANCE, 18);
   ObjectSetText(name, txt, 9, "Consolas", clrWhite);
}

//====================================================
// Strict consecutive shared-event rebuild
//====================================================
void RebuildSMTState()
{
   int barsCount = MathMin(Bars, InpHistoryBarsToProcess + InpPivotLookback + 20);
   if(barsCount <= InpPivotLookback * 2 + 10)
      return;

   datetime baseTime[];
   double   baseHigh[];
   double   baseLow[];

   ArrayResize(baseTime, barsCount);
   ArrayResize(baseHigh, barsCount);
   ArrayResize(baseLow,  barsCount);

   ArraySetAsSeries(baseTime, true);
   ArraySetAsSeries(baseHigh, true);
   ArraySetAsSeries(baseLow,  true);

   for(int i = 0; i < barsCount; i++)
   {
      baseTime[i] = Time[i];
      baseHigh[i] = High[i];
      baseLow[i]  = Low[i];
   }

   g_baseHighCount = 0;
   g_baseLowCount  = 0;
   g_s1High = g_s1Low = 0;
   g_s2High = g_s2Low = 0;
   g_s3High = g_s3Low = 0;
   g_s4High = g_s4Low = 0;

   // Cache symbol data once
   datetime s1Time[], s2Time[], s3Time[], s4Time[];
   double   s1HighArr[], s2HighArr[], s3HighArr[], s4HighArr[];
   double   s1LowArr[],  s2LowArr[],  s3LowArr[],  s4LowArr[];
   int      s1Count = 0, s2Count = 0, s3Count = 0, s4Count = 0;

   if(InpUseSymbol1) CacheSymbolData(InpSymbol1, Period(), barsCount, s1Time, s1HighArr, s1LowArr, s1Count);
   if(InpUseSymbol2) CacheSymbolData(InpSymbol2, Period(), barsCount, s2Time, s2HighArr, s2LowArr, s2Count);
   if(InpUseSymbol3) CacheSymbolData(InpSymbol3, Period(), barsCount, s3Time, s3HighArr, s3LowArr, s3Count);
   if(InpUseSymbol4) CacheSymbolData(InpSymbol4, Period(), barsCount, s4Time, s4HighArr, s4LowArr, s4Count);

   int L = InpPivotLookback;
   int startBar = MathMin(barsCount - L - 1, InpHistoryBarsToProcess);
   int endBar   = L;

   // -------------------------
   // HIGH EVENTS
   // -------------------------
   int      highEventBaseShift[];
   datetime highEventBaseTime[];
   double   highEventBasePrice[];

   bool     highEvtS1Has[];
   bool     highEvtS2Has[];
   bool     highEvtS3Has[];
   bool     highEvtS4Has[];

   double   highEvtS1Price[];
   double   highEvtS2Price[];
   double   highEvtS3Price[];
   double   highEvtS4Price[];

   int highEvents = 0;

   ArrayResize(highEventBaseShift, 0);
   ArrayResize(highEventBaseTime, 0);
   ArrayResize(highEventBasePrice, 0);

   ArrayResize(highEvtS1Has, 0);
   ArrayResize(highEvtS2Has, 0);
   ArrayResize(highEvtS3Has, 0);
   ArrayResize(highEvtS4Has, 0);

   ArrayResize(highEvtS1Price, 0);
   ArrayResize(highEvtS2Price, 0);
   ArrayResize(highEvtS3Price, 0);
   ArrayResize(highEvtS4Price, 0);

   for(int iH = startBar; iH >= endBar; iH--)
   {
      if(!IsPivotHighArr(baseHigh, iH, L, barsCount))
         continue;

      g_baseHighCount++;

      int sh;
      double p1 = 0.0, p2 = 0.0, p3 = 0.0, p4 = 0.0;
      bool has1 = false, has2 = false, has3 = false, has4 = false;

      if(InpUseSymbol1) has1 = FindNearestCachedPivotShift(baseTime, s1Time, s1HighArr, iH, s1Count, true,  L, InpMaxPivotTimeGapBars, sh, p1);
      if(InpUseSymbol2) has2 = FindNearestCachedPivotShift(baseTime, s2Time, s2HighArr, iH, s2Count, true,  L, InpMaxPivotTimeGapBars, sh, p2);
      if(InpUseSymbol3) has3 = FindNearestCachedPivotShift(baseTime, s3Time, s3HighArr, iH, s3Count, true,  L, InpMaxPivotTimeGapBars, sh, p3);
      if(InpUseSymbol4) has4 = FindNearestCachedPivotShift(baseTime, s4Time, s4HighArr, iH, s4Count, true,  L, InpMaxPivotTimeGapBars, sh, p4);

      int idx = highEvents;
      highEvents++;

      ArrayResize(highEventBaseShift, highEvents);
      ArrayResize(highEventBaseTime, highEvents);
      ArrayResize(highEventBasePrice, highEvents);

      ArrayResize(highEvtS1Has, highEvents);
      ArrayResize(highEvtS2Has, highEvents);
      ArrayResize(highEvtS3Has, highEvents);
      ArrayResize(highEvtS4Has, highEvents);

      ArrayResize(highEvtS1Price, highEvents);
      ArrayResize(highEvtS2Price, highEvents);
      ArrayResize(highEvtS3Price, highEvents);
      ArrayResize(highEvtS4Price, highEvents);

      highEventBaseShift[idx] = iH;
      highEventBaseTime[idx]  = baseTime[iH];
      highEventBasePrice[idx] = baseHigh[iH];

      highEvtS1Has[idx] = has1; highEvtS1Price[idx] = p1;
      highEvtS2Has[idx] = has2; highEvtS2Price[idx] = p2;
      highEvtS3Has[idx] = has3; highEvtS3Price[idx] = p3;
      highEvtS4Has[idx] = has4; highEvtS4Price[idx] = p4;
   }

   for(int eH = 1; eH < highEvents; eH++)
   {
      int prevH = eH - 1;
      string basketTextH = "";

      double dBaseH = highEventBasePrice[eH] - highEventBasePrice[prevH];

      if(InpUseSymbol1 && highEvtS1Has[prevH] && highEvtS1Has[eH])
      {
         double dSymRaw = highEvtS1Price[eH] - highEvtS1Price[prevH];
         double dSym    = InpInvertSymbol1 ? -dSymRaw : dSymRaw;
         if((dBaseH * dSym) < 0.0)
         {
            g_s1High++;
            basketTextH = (basketTextH == "" ? InpSymbol1 + (InpInvertSymbol1 ? " (Inv)" : "") : basketTextH + " | " + InpSymbol1 + (InpInvertSymbol1 ? " (Inv)" : ""));
         }
      }

      if(InpUseSymbol2 && highEvtS2Has[prevH] && highEvtS2Has[eH])
      {
         double dSymRaw = highEvtS2Price[eH] - highEvtS2Price[prevH];
         double dSym    = InpInvertSymbol2 ? -dSymRaw : dSymRaw;
         if((dBaseH * dSym) < 0.0)
         {
            g_s2High++;
            basketTextH = (basketTextH == "" ? InpSymbol2 + (InpInvertSymbol2 ? " (Inv)" : "") : basketTextH + " | " + InpSymbol2 + (InpInvertSymbol2 ? " (Inv)" : ""));
         }
      }

      if(InpUseSymbol3 && highEvtS3Has[prevH] && highEvtS3Has[eH])
      {
         double dSymRaw = highEvtS3Price[eH] - highEvtS3Price[prevH];
         double dSym    = InpInvertSymbol3 ? -dSymRaw : dSymRaw;
         if((dBaseH * dSym) < 0.0)
         {
            g_s3High++;
            basketTextH = (basketTextH == "" ? InpSymbol3 + (InpInvertSymbol3 ? " (Inv)" : "") : basketTextH + " | " + InpSymbol3 + (InpInvertSymbol3 ? " (Inv)" : ""));
         }
      }

      if(InpUseSymbol4 && highEvtS4Has[prevH] && highEvtS4Has[eH])
      {
         double dSymRaw = highEvtS4Price[eH] - highEvtS4Price[prevH];
         double dSym    = InpInvertSymbol4 ? -dSymRaw : dSymRaw;
         if((dBaseH * dSym) < 0.0)
         {
            g_s4High++;
            basketTextH = (basketTextH == "" ? InpSymbol4 + (InpInvertSymbol4 ? " (Inv)" : "") : basketTextH + " | " + InpSymbol4 + (InpInvertSymbol4 ? " (Inv)" : ""));
         }
      }

      if(basketTextH != "")
      {
         string lnH = InpObjectPrefix + "H_BASKET_" + IntegerToString((int)highEventBaseTime[eH]);
         DrawTrendLineIfMissing(lnH, highEventBaseTime[prevH], highEventBasePrice[prevH], highEventBaseTime[eH], highEventBasePrice[eH], InpSwingHighColor);

         string lblH = InpObjectPrefix + "HLBL_" + IntegerToString((int)highEventBaseTime[eH]);
         DrawTextLabelIfMissing(lblH, highEventBaseTime[eH], highEventBasePrice[eH], basketTextH, InpSwingHighColor, true);

         if(eH == highEvents - 1)
            FireAlert(true, basketTextH, highEventBaseTime[eH]);
      }
   }

   // -------------------------
   // LOW EVENTS
   // -------------------------
   int      lowEventBaseShift[];
   datetime lowEventBaseTime[];
   double   lowEventBasePrice[];

   bool     lowEvtS1Has[];
   bool     lowEvtS2Has[];
   bool     lowEvtS3Has[];
   bool     lowEvtS4Has[];

   double   lowEvtS1Price[];
   double   lowEvtS2Price[];
   double   lowEvtS3Price[];
   double   lowEvtS4Price[];

   int lowEvents = 0;

   ArrayResize(lowEventBaseShift, 0);
   ArrayResize(lowEventBaseTime, 0);
   ArrayResize(lowEventBasePrice, 0);

   ArrayResize(lowEvtS1Has, 0);
   ArrayResize(lowEvtS2Has, 0);
   ArrayResize(lowEvtS3Has, 0);
   ArrayResize(lowEvtS4Has, 0);

   ArrayResize(lowEvtS1Price, 0);
   ArrayResize(lowEvtS2Price, 0);
   ArrayResize(lowEvtS3Price, 0);
   ArrayResize(lowEvtS4Price, 0);

   for(int iL = startBar; iL >= endBar; iL--)
   {
      if(!IsPivotLowArr(baseLow, iL, L, barsCount))
         continue;

      g_baseLowCount++;

      int sh2;
      double p1L = 0.0, p2L = 0.0, p3L = 0.0, p4L = 0.0;
      bool has1L = false, has2L = false, has3L = false, has4L = false;

      if(InpUseSymbol1) has1L = FindNearestCachedPivotShift(baseTime, s1Time, s1LowArr, iL, s1Count, false, L, InpMaxPivotTimeGapBars, sh2, p1L);
      if(InpUseSymbol2) has2L = FindNearestCachedPivotShift(baseTime, s2Time, s2LowArr, iL, s2Count, false, L, InpMaxPivotTimeGapBars, sh2, p2L);
      if(InpUseSymbol3) has3L = FindNearestCachedPivotShift(baseTime, s3Time, s3LowArr, iL, s3Count, false, L, InpMaxPivotTimeGapBars, sh2, p3L);
      if(InpUseSymbol4) has4L = FindNearestCachedPivotShift(baseTime, s4Time, s4LowArr, iL, s4Count, false, L, InpMaxPivotTimeGapBars, sh2, p4L);

      int idxL = lowEvents;
      lowEvents++;

      ArrayResize(lowEventBaseShift, lowEvents);
      ArrayResize(lowEventBaseTime, lowEvents);
      ArrayResize(lowEventBasePrice, lowEvents);

      ArrayResize(lowEvtS1Has, lowEvents);
      ArrayResize(lowEvtS2Has, lowEvents);
      ArrayResize(lowEvtS3Has, lowEvents);
      ArrayResize(lowEvtS4Has, lowEvents);

      ArrayResize(lowEvtS1Price, lowEvents);
      ArrayResize(lowEvtS2Price, lowEvents);
      ArrayResize(lowEvtS3Price, lowEvents);
      ArrayResize(lowEvtS4Price, lowEvents);

      lowEventBaseShift[idxL] = iL;
      lowEventBaseTime[idxL]  = baseTime[iL];
      lowEventBasePrice[idxL] = baseLow[iL];

      lowEvtS1Has[idxL] = has1L; lowEvtS1Price[idxL] = p1L;
      lowEvtS2Has[idxL] = has2L; lowEvtS2Price[idxL] = p2L;
      lowEvtS3Has[idxL] = has3L; lowEvtS3Price[idxL] = p3L;
      lowEvtS4Has[idxL] = has4L; lowEvtS4Price[idxL] = p4L;
   }

   for(int eL = 1; eL < lowEvents; eL++)
   {
      int prevL = eL - 1;
      string basketTextL = "";

      double dBaseL = lowEventBasePrice[eL] - lowEventBasePrice[prevL];

      if(InpUseSymbol1 && lowEvtS1Has[prevL] && lowEvtS1Has[eL])
      {
         double dSymRaw = lowEvtS1Price[eL] - lowEvtS1Price[prevL];
         double dSym    = InpInvertSymbol1 ? -dSymRaw : dSymRaw;
         if((dBaseL * dSym) < 0.0)
         {
            g_s1Low++;
            basketTextL = (basketTextL == "" ? InpSymbol1 + (InpInvertSymbol1 ? " (Inv)" : "") : basketTextL + " | " + InpSymbol1 + (InpInvertSymbol1 ? " (Inv)" : ""));
         }
      }

      if(InpUseSymbol2 && lowEvtS2Has[prevL] && lowEvtS2Has[eL])
      {
         double dSymRaw = lowEvtS2Price[eL] - lowEvtS2Price[prevL];
         double dSym    = InpInvertSymbol2 ? -dSymRaw : dSymRaw;
         if((dBaseL * dSym) < 0.0)
         {
            g_s2Low++;
            basketTextL = (basketTextL == "" ? InpSymbol2 + (InpInvertSymbol2 ? " (Inv)" : "") : basketTextL + " | " + InpSymbol2 + (InpInvertSymbol2 ? " (Inv)" : ""));
         }
      }

      if(InpUseSymbol3 && lowEvtS3Has[prevL] && lowEvtS3Has[eL])
      {
         double dSymRaw = lowEvtS3Price[eL] - lowEvtS3Price[prevL];
         double dSym    = InpInvertSymbol3 ? -dSymRaw : dSymRaw;
         if((dBaseL * dSym) < 0.0)
         {
            g_s3Low++;
            basketTextL = (basketTextL == "" ? InpSymbol3 + (InpInvertSymbol3 ? " (Inv)" : "") : basketTextL + " | " + InpSymbol3 + (InpInvertSymbol3 ? " (Inv)" : ""));
         }
      }

      if(InpUseSymbol4 && lowEvtS4Has[prevL] && lowEvtS4Has[eL])
      {
         double dSymRaw = lowEvtS4Price[eL] - lowEvtS4Price[prevL];
         double dSym    = InpInvertSymbol4 ? -dSymRaw : dSymRaw;
         if((dBaseL * dSym) < 0.0)
         {
            g_s4Low++;
            basketTextL = (basketTextL == "" ? InpSymbol4 + (InpInvertSymbol4 ? " (Inv)" : "") : basketTextL + " | " + InpSymbol4 + (InpInvertSymbol4 ? " (Inv)" : ""));
         }
      }

      if(basketTextL != "")
      {
         string lnL = InpObjectPrefix + "L_BASKET_" + IntegerToString((int)lowEventBaseTime[eL]);
         DrawTrendLineIfMissing(lnL, lowEventBaseTime[prevL], lowEventBasePrice[prevL], lowEventBaseTime[eL], lowEventBasePrice[eL], InpSwingLowColor);

         string lblL = InpObjectPrefix + "LLBL_" + IntegerToString((int)lowEventBaseTime[eL]);
         DrawTextLabelIfMissing(lblL, lowEventBaseTime[eL], lowEventBasePrice[eL], basketTextL, InpSwingLowColor, false);

         if(eL == lowEvents - 1)
            FireAlert(false, basketTextL, lowEventBaseTime[eL]);
      }
   }

   UpdateDashboard();
}

//====================================================
// MT4 lifecycle
//====================================================
int init()
{
   IndicatorShortName("Theorem SMT Divergences Unified Event");
   return(0);
}

int deinit()
{
   CleanupAllIndicatorObjects();
   return(0);
}

int start()
{
   if(Bars <= InpPivotLookback * 2 + 10)
      return(0);

   if(InpEnforceM15 && Period() != PERIOD_M15)
   {
      Comment("Theorem SMT: Attach to M15");
      return(0);
   }
   else
   {
      Comment("");
   }

   if(g_firstBuildDone && Time[0] == g_lastProcessedBarTime)
      return(0);

   g_lastProcessedBarTime = Time[0];
   RebuildSMTState();
   g_firstBuildDone = true;

   return(0);
}