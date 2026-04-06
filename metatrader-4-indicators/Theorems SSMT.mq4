#property strict
#property indicator_chart_window

input bool     InpEnforceM15          = true;

input string   InpQ1Start             = "20:30";
input string   InpQ2Start             = "02:30";
input string   InpQ3Start             = "08:30";
input string   InpQ4Start             = "14:30";

input bool     InpUseSymbol1          = true;
input string   InpSymbol1             = "US500";

input bool     InpUseSymbol2          = true;
input string   InpSymbol2             = "US30";

input bool     InpUseSymbol3          = false;
input string   InpSymbol3             = "NAS100";

input bool     InpUseSymbol4          = false;
input string   InpSymbol4             = "GER40";

input bool     InpShowSSMT1           = true;
input bool     InpShowSSMT2           = true;
input bool     InpShowHiddenSSMT1     = true;
input bool     InpShowHiddenSSMT2     = true;

input color    InpClr_Q1_Q2           = clrRed;
input color    InpClr_Q2_Q3           = clrDodgerBlue;
input color    InpClr_Q3_Q4           = clrLimeGreen;
input color    InpClr_Q4_Q1           = clrOrange;

input bool     InpDrawLabels          = true;
input bool     InpDrawArrows          = true;
input bool     InpDrawLines           = true;
input int      InpFontSize            = 8;
input int      InpArrowCodeHigh       = 234;
input int      InpArrowCodeLow        = 233;
input int      InpArrowSize           = 1;
input int      InpLineWidth           = 2;
input ENUM_LINE_STYLE InpLineStyle    = STYLE_SOLID;

input int      InpBarsToBackpaint     = 500;
input int      InpMaxSignalsPerBar    = 20;

input bool     InpEnableAlerts        = false;
input bool     InpAlertOncePerBar     = true;

input double   InpPriceEpsilonPoints  = 0.5;
input string   InpObjectPrefix        = "THEOREM_QSSMT_";

datetime g_lastProcessedBar = 0;
datetime g_lastAlertBar     = 0;

string TfToStr(int tf)
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
   }
   return("TF");
}

bool SymbolReady(string sym)
{
   if(sym == "" || sym == NULL)
      return(false);

   if(!SymbolSelect(sym, true))
      return(false);

   if(iBars(sym, Period()) < 100)
      return(false);

   return(true);
}

double EpsPrice()
{
   return(InpPriceEpsilonPoints * Point);
}

int ParseHHMM(string hhmm)
{
   if(StringLen(hhmm) != 5 || StringSubstr(hhmm, 2, 1) != ":")
      return(-1);

   int hh = StrToInteger(StringSubstr(hhmm, 0, 2));
   int mm = StrToInteger(StringSubstr(hhmm, 3, 2));

   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return(-1);

   return(hh * 60 + mm);
}

datetime DateOnly(datetime t)
{
   return(StrToTime(TimeToString(t, TIME_DATE)));
}

bool GetQuarterStartMinutes(int &qMins[])
{
   ArrayResize(qMins, 4);

   qMins[0] = ParseHHMM(InpQ1Start);
   qMins[1] = ParseHHMM(InpQ2Start);
   qMins[2] = ParseHHMM(InpQ3Start);
   qMins[3] = ParseHHMM(InpQ4Start);

   if(qMins[0] < 0 || qMins[1] < 0 || qMins[2] < 0 || qMins[3] < 0)
      return(false);

   return(true);
}

string QuarterName(int q)
{
   if(q == 0) return("Q1");
   if(q == 1) return("Q2");
   if(q == 2) return("Q3");
   if(q == 3) return("Q4");
   return("Q?");
}

string TransitionText(int prevQ, int curQ)
{
   return(QuarterName(prevQ) + "->" + QuarterName(curQ));
}

color TransitionColor(int prevQ, int curQ)
{
   if(prevQ == 0 && curQ == 1) return(InpClr_Q1_Q2);
   if(prevQ == 1 && curQ == 2) return(InpClr_Q2_Q3);
   if(prevQ == 2 && curQ == 3) return(InpClr_Q3_Q4);
   if(prevQ == 3 && curQ == 0) return(InpClr_Q4_Q1);
   return(clrWhite);
}

void BuildQuarterOffsets(const int &qMins[], int &qOffsets[])
{
   ArrayResize(qOffsets, 4);

   qOffsets[0] = qMins[0];
   for(int i = 1; i < 4; i++)
   {
      qOffsets[i] = qMins[i];
      while(qOffsets[i] <= qOffsets[i - 1])
         qOffsets[i] += 1440;
   }
}

bool ResolveQuarterWindows(datetime t,
                           datetime &prevStart,
                           datetime &prevEnd,
                           datetime &curStart,
                           datetime &curEnd,
                           int &prevQ,
                           int &curQ)
{
   int qMins[];
   if(!GetQuarterStartMinutes(qMins))
      return(false);

   int qOffsets[];
   BuildQuarterOffsets(qMins, qOffsets);

   datetime baseDay = DateOnly(t);

   curStart = 0;
   curEnd   = 0;
   prevStart = 0;
   prevEnd   = 0;
   curQ = -1;
   prevQ = -1;

   for(int d = -3; d <= 1; d++)
   {
      datetime anchor = baseDay + d * 86400;

      datetime starts[];
      ArrayResize(starts, 4);

      for(int q = 0; q < 4; q++)
         starts[q] = anchor + qOffsets[q] * 60;

      for(int q2 = 0; q2 < 4; q2++)
      {
         datetime s = starts[q2];
         datetime e = (q2 < 3) ? starts[q2 + 1] : (anchor + (qOffsets[0] + 1440) * 60);

         if(t >= s && t < e)
         {
            curStart = s;
            curEnd   = e;
            curQ     = q2;

            if(q2 > 0)
            {
               prevStart = starts[q2 - 1];
               prevEnd   = s;
               prevQ     = q2 - 1;
            }
            else
            {
               prevStart = anchor + (qOffsets[3] - 1440) * 60;
               prevEnd   = s;
               prevQ     = 3;
            }

            return(true);
         }
      }
   }

   return(false);
}

bool GetQuarterStats(string sym,
                     int tf,
                     datetime qStart,
                     datetime qEnd,
                     double &wickHigh,
                     double &wickLow,
                     double &bodyHigh,
                     double &bodyLow,
                     datetime &wickHighTime,
                     datetime &wickLowTime,
                     datetime &bodyHighTime,
                     datetime &bodyLowTime)
{
   wickHigh = -DBL_MAX;
   wickLow  =  DBL_MAX;
   bodyHigh = -DBL_MAX;
   bodyLow  =  DBL_MAX;

   wickHighTime = 0;
   wickLowTime  = 0;
   bodyHighTime = 0;
   bodyLowTime  = 0;

   int shiftOld = iBarShift(sym, tf, qStart, false);
   int shiftNew = iBarShift(sym, tf, qEnd - 1, false);

   if(shiftOld < 0 || shiftNew < 0)
      return(false);

   bool found = false;

   for(int s = shiftOld; s >= shiftNew; s--)
   {
      datetime bt = iTime(sym, tf, s);
      if(bt < qStart || bt >= qEnd)
         continue;

      double o = iOpen(sym, tf, s);
      double h = iHigh(sym, tf, s);
      double l = iLow(sym, tf, s);
      double c = iClose(sym, tf, s);

      double bh = MathMax(o, c);
      double bl = MathMin(o, c);

      if(h > wickHigh)
      {
         wickHigh = h;
         wickHighTime = bt;
      }
      if(l < wickLow)
      {
         wickLow = l;
         wickLowTime = bt;
      }
      if(bh > bodyHigh)
      {
         bodyHigh = bh;
         bodyHighTime = bt;
      }
      if(bl < bodyLow)
      {
         bodyLow = bl;
         bodyLowTime = bt;
      }

      found = true;
   }

   return(found);
}

bool GetSymbolBarAtTime(string sym, int tf, datetime targetBarTime,
                        double &o, double &h, double &l, double &c)
{
   int s = iBarShift(sym, tf, targetBarTime, false);
   if(s < 0)
      return(false);

   datetime bt = iTime(sym, tf, s);
   if(MathAbs((int)(bt - targetBarTime)) > PeriodSeconds())
      return(false);

   o = iOpen(sym, tf, s);
   h = iHigh(sym, tf, s);
   l = iLow(sym, tf, s);
   c = iClose(sym, tf, s);

   return(true);
}

void DrawArrowIfMissing(string name, datetime t, double p, color clr, bool isHighSide)
{
   if(!InpDrawArrows)
      return;

   if(ObjectFind(name) >= 0)
      return;

   if(!ObjectCreate(name, OBJ_ARROW, 0, t, p))
      return;

   ObjectSet(name, OBJPROP_ARROWCODE, isHighSide ? InpArrowCodeHigh : InpArrowCodeLow);
   ObjectSet(name, OBJPROP_COLOR, clr);
   ObjectSet(name, OBJPROP_WIDTH, InpArrowSize);
}

void DrawTextIfMissing(string name, datetime t, double p, string txt, color clr)
{
   if(!InpDrawLabels)
      return;

   if(ObjectFind(name) >= 0)
      return;

   if(!ObjectCreate(name, OBJ_TEXT, 0, t, p))
      return;

   ObjectSetText(name, txt, InpFontSize, "Arial", clr);
}

void DrawLineIfMissing(string name,
                       datetime t1,
                       double p1,
                       datetime t2,
                       double p2,
                       color clr)
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

void FireAlert(string msg, datetime barTime)
{
   if(!InpEnableAlerts)
      return;

   if(InpAlertOncePerBar)
   {
      if(g_lastAlertBar == barTime)
         return;
      g_lastAlertBar = barTime;
   }

   Alert(msg);
}

void DeleteAllPrefixObjects()
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, InpObjectPrefix, 0) == 0)
         ObjectDelete(name);
   }
}

void DrawSignal(datetime barTime,
                double refHigh,
                double refLow,
                color clr,
                bool isHighSide,
                string signalType,
                string transition,
                string leader,
                string lagger,
                string compareSymbol,
                int stackIndex,
                datetime lineStartTime,
                double lineStartPrice,
                datetime lineEndTime,
                double lineEndPrice)
{
   if(stackIndex >= InpMaxSignalsPerBar)
      return;

   string side = isHighSide ? "H" : "L";
   string txt = transition + " " + signalType + " " + side + " " + leader + " vs " + lagger;

   double range = WindowPriceMax() - WindowPriceMin();
   if(range <= 0) range = 100 * Point;
   double step = range * 0.015;

   double price = isHighSide ? (refHigh + step * (stackIndex + 1))
                             : (refLow  - step * (stackIndex + 1));

   string baseKey = InpObjectPrefix + signalType + "_" + side + "_" + compareSymbol + "_" + IntegerToString((int)barTime);

   DrawLineIfMissing(baseKey + "_L", lineStartTime, lineStartPrice, lineEndTime, lineEndPrice, clr);
   DrawArrowIfMissing(baseKey + "_A", barTime, price, clr, isHighSide);
   DrawTextIfMissing(baseKey + "_T", barTime, price, txt, clr);

   if(barTime == Time[1])
      FireAlert(Symbol() + " " + TfToStr(Period()) + " " + txt, barTime);
}

void CheckSignalsAgainstSymbol(string cmpSym,
                               bool enabled,
                               datetime barTime,
                               double baseOpen,
                               double baseHigh,
                               double baseLow,
                               double baseClose,
                               double basePrevWickHigh,
                               double basePrevWickLow,
                               double basePrevBodyHigh,
                               double basePrevBodyLow,
                               datetime basePrevWickHighTime,
                               datetime basePrevWickLowTime,
                               datetime basePrevBodyHighTime,
                               datetime basePrevBodyLowTime,
                               datetime prevStart,
                               datetime prevEnd,
                               int prevQ,
                               int curQ,
                               int &stackHigh,
                               int &stackLow)
{
   if(!enabled || !SymbolReady(cmpSym))
      return;

   double cmpPrevWickHigh, cmpPrevWickLow, cmpPrevBodyHigh, cmpPrevBodyLow;
   datetime cmpPrevWickHighTime, cmpPrevWickLowTime, cmpPrevBodyHighTime, cmpPrevBodyLowTime;

   if(!GetQuarterStats(cmpSym, Period(), prevStart, prevEnd,
                       cmpPrevWickHigh, cmpPrevWickLow, cmpPrevBodyHigh, cmpPrevBodyLow,
                       cmpPrevWickHighTime, cmpPrevWickLowTime, cmpPrevBodyHighTime, cmpPrevBodyLowTime))
      return;

   double co, ch, cl, cc;
   if(!GetSymbolBarAtTime(cmpSym, Period(), barTime, co, ch, cl, cc))
      return;

   double eps = EpsPrice();

   bool bCloseAbovePrevWick = (baseClose > basePrevWickHigh + eps);
   bool bCloseBelowPrevWick = (baseClose < basePrevWickLow  - eps);
   bool bWickAbovePrevWick  = (baseHigh  > basePrevWickHigh + eps);
   bool bWickBelowPrevWick  = (baseLow   < basePrevWickLow  - eps);

   bool bWickAbovePrevBody  = (baseHigh  > basePrevBodyHigh + eps);
   bool bWickBelowPrevBody  = (baseLow   < basePrevBodyLow  - eps);
   bool bCloseAbovePrevBody = (baseClose > basePrevBodyHigh + eps);
   bool bCloseBelowPrevBody = (baseClose < basePrevBodyLow  - eps);

   bool cCloseAbovePrevWick = (cc > cmpPrevWickHigh + eps);
   bool cCloseBelowPrevWick = (cc < cmpPrevWickLow  - eps);
   bool cWickAbovePrevWick  = (ch > cmpPrevWickHigh + eps);
   bool cWickBelowPrevWick  = (cl < cmpPrevWickLow  - eps);

   bool cWickAbovePrevBody  = (ch > cmpPrevBodyHigh + eps);
   bool cWickBelowPrevBody  = (cl < cmpPrevBodyLow  - eps);
   bool cCloseAbovePrevBody = (cc > cmpPrevBodyHigh + eps);
   bool cCloseBelowPrevBody = (cc < cmpPrevBodyLow  - eps);

   string transition = TransitionText(prevQ, curQ);
   color  sigClr     = TransitionColor(prevQ, curQ);

   string leader;
   string lagger;

   if(InpShowSSMT1)
   {
      if(bCloseAbovePrevWick != cCloseAbovePrevWick)
      {
         leader = bCloseAbovePrevWick ? Symbol() : cmpSym;
         lagger = bCloseAbovePrevWick ? cmpSym : Symbol();
         DrawSignal(barTime, baseHigh, baseLow, sigClr, true, "SSMT1", transition, leader, lagger, cmpSym, stackHigh++,
                    basePrevWickHighTime, basePrevWickHigh, barTime, baseHigh);
      }

      if(bCloseBelowPrevWick != cCloseBelowPrevWick)
      {
         leader = bCloseBelowPrevWick ? Symbol() : cmpSym;
         lagger = bCloseBelowPrevWick ? cmpSym : Symbol();
         DrawSignal(barTime, baseHigh, baseLow, sigClr, false, "SSMT1", transition, leader, lagger, cmpSym, stackLow++,
                    basePrevWickLowTime, basePrevWickLow, barTime, baseLow);
      }
   }

   if(InpShowSSMT2)
   {
      if(bWickAbovePrevWick != cWickAbovePrevWick)
      {
         leader = bWickAbovePrevWick ? Symbol() : cmpSym;
         lagger = bWickAbovePrevWick ? cmpSym : Symbol();
         DrawSignal(barTime, baseHigh, baseLow, sigClr, true, "SSMT2", transition, leader, lagger, cmpSym, stackHigh++,
                    basePrevWickHighTime, basePrevWickHigh, barTime, baseHigh);
      }

      if(bWickBelowPrevWick != cWickBelowPrevWick)
      {
         leader = bWickBelowPrevWick ? Symbol() : cmpSym;
         lagger = bWickBelowPrevWick ? cmpSym : Symbol();
         DrawSignal(barTime, baseHigh, baseLow, sigClr, false, "SSMT2", transition, leader, lagger, cmpSym, stackLow++,
                    basePrevWickLowTime, basePrevWickLow, barTime, baseLow);
      }
   }

   if(InpShowHiddenSSMT1)
   {
      if(bWickAbovePrevBody != cWickAbovePrevBody)
      {
         leader = bWickAbovePrevBody ? Symbol() : cmpSym;
         lagger = bWickAbovePrevBody ? cmpSym : Symbol();
         DrawSignal(barTime, baseHigh, baseLow, sigClr, true, "H-SSMT1", transition, leader, lagger, cmpSym, stackHigh++,
                    basePrevBodyHighTime, basePrevBodyHigh, barTime, baseHigh);
      }

      if(bWickBelowPrevBody != cWickBelowPrevBody)
      {
         leader = bWickBelowPrevBody ? Symbol() : cmpSym;
         lagger = bWickBelowPrevBody ? cmpSym : Symbol();
         DrawSignal(barTime, baseHigh, baseLow, sigClr, false, "H-SSMT1", transition, leader, lagger, cmpSym, stackLow++,
                    basePrevBodyLowTime, basePrevBodyLow, barTime, baseLow);
      }
   }

   if(InpShowHiddenSSMT2)
   {
      if(bCloseAbovePrevBody != cCloseAbovePrevBody)
      {
         leader = bCloseAbovePrevBody ? Symbol() : cmpSym;
         lagger = bCloseAbovePrevBody ? cmpSym : Symbol();
         DrawSignal(barTime, baseHigh, baseLow, sigClr, true, "H-SSMT2", transition, leader, lagger, cmpSym, stackHigh++,
                    basePrevBodyHighTime, basePrevBodyHigh, barTime, baseHigh);
      }

      if(bCloseBelowPrevBody != cCloseBelowPrevBody)
      {
         leader = bCloseBelowPrevBody ? Symbol() : cmpSym;
         lagger = bCloseBelowPrevBody ? cmpSym : Symbol();
         DrawSignal(barTime, baseHigh, baseLow, sigClr, false, "H-SSMT2", transition, leader, lagger, cmpSym, stackLow++,
                    basePrevBodyLowTime, basePrevBodyLow, barTime, baseLow);
      }
   }
}

void ProcessHistoricalBar(int chartShift)
{
   if(chartShift < 1 || chartShift >= Bars)
      return;

   datetime barTime = Time[chartShift];

   datetime prevStart, prevEnd, curStart, curEnd;
   int prevQ, curQ;

   if(!ResolveQuarterWindows(barTime, prevStart, prevEnd, curStart, curEnd, prevQ, curQ))
      return;

   double basePrevWickHigh, basePrevWickLow, basePrevBodyHigh, basePrevBodyLow;
   datetime basePrevWickHighTime, basePrevWickLowTime, basePrevBodyHighTime, basePrevBodyLowTime;

   if(!GetQuarterStats(Symbol(), Period(), prevStart, prevEnd,
                       basePrevWickHigh, basePrevWickLow, basePrevBodyHigh, basePrevBodyLow,
                       basePrevWickHighTime, basePrevWickLowTime, basePrevBodyHighTime, basePrevBodyLowTime))
      return;

   double baseOpen  = Open[chartShift];
   double baseHigh  = High[chartShift];
   double baseLow   = Low[chartShift];
   double baseClose = Close[chartShift];

   int stackHigh = 0;
   int stackLow  = 0;

   CheckSignalsAgainstSymbol(InpSymbol1, InpUseSymbol1, barTime,
                             baseOpen, baseHigh, baseLow, baseClose,
                             basePrevWickHigh, basePrevWickLow, basePrevBodyHigh, basePrevBodyLow,
                             basePrevWickHighTime, basePrevWickLowTime, basePrevBodyHighTime, basePrevBodyLowTime,
                             prevStart, prevEnd, prevQ, curQ, stackHigh, stackLow);

   CheckSignalsAgainstSymbol(InpSymbol2, InpUseSymbol2, barTime,
                             baseOpen, baseHigh, baseLow, baseClose,
                             basePrevWickHigh, basePrevWickLow, basePrevBodyHigh, basePrevBodyLow,
                             basePrevWickHighTime, basePrevWickLowTime, basePrevBodyHighTime, basePrevBodyLowTime,
                             prevStart, prevEnd, prevQ, curQ, stackHigh, stackLow);

   CheckSignalsAgainstSymbol(InpSymbol3, InpUseSymbol3, barTime,
                             baseOpen, baseHigh, baseLow, baseClose,
                             basePrevWickHigh, basePrevWickLow, basePrevBodyHigh, basePrevBodyLow,
                             basePrevWickHighTime, basePrevWickLowTime, basePrevBodyHighTime, basePrevBodyLowTime,
                             prevStart, prevEnd, prevQ, curQ, stackHigh, stackLow);

   CheckSignalsAgainstSymbol(InpSymbol4, InpUseSymbol4, barTime,
                             baseOpen, baseHigh, baseLow, baseClose,
                             basePrevWickHigh, basePrevWickLow, basePrevBodyHigh, basePrevBodyLow,
                             basePrevWickHighTime, basePrevWickLowTime, basePrevBodyHighTime, basePrevBodyLowTime,
                             prevStart, prevEnd, prevQ, curQ, stackHigh, stackLow);
}

void RebuildBackpaint()
{
   DeleteAllPrefixObjects();

   int maxShift = MathMin(Bars - 1, InpBarsToBackpaint);
   if(maxShift < 1)
      return;

   for(int shift = maxShift; shift >= 1; shift--)
      ProcessHistoricalBar(shift);
}

int init()
{
   IndicatorShortName("Theorem Quarter SSMT Backpaint Lines");
   return(0);
}

int deinit()
{
   DeleteAllPrefixObjects();
   return(0);
}

int start()
{
   if(InpEnforceM15 && Period() != PERIOD_M15)
   {
      Comment("Theorem Quarter SSMT Backpaint Lines: Attach to M15");
      return(0);
   }
   else
   {
      Comment("");
   }

   if(Bars < 50)
      return(0);

   int qMins[];
   if(!GetQuarterStartMinutes(qMins))
   {
      Comment("Quarter time inputs invalid. Use HH:MM format.");
      return(0);
   }

   if(g_lastProcessedBar == Time[0])
      return(0);

   g_lastProcessedBar = Time[0];
   RebuildBackpaint();

   return(0);
}