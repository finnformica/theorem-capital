#property strict
#property indicator_separate_window
#property indicator_buffers 2

// ============================================================
//  Sessions Bands in SEPARATE INDICATOR WINDOW (RSI-style pane)
//  - Draws rectangles/text as chart objects in this indicator subwindow
//
//  LAYER STACK (top -> bottom):
//   - 22.5M cycle layer
//   - 90M cycle layer
//   - Day cycle layer
//   - Week cycle layer
//   - Month cycle layer
//   - Year cycle layer
//   - 4 year cycle layer
//
//  - Forces axis 0..1 by using 2 invisible buffers
//
//  OPTIMIZED:
//   1) No full rebuild on every tick
//   2) No full rescan of chart objects on every tick
//   3) Heavy work runs only on first run / new bar / TF change / placement change
// ============================================================

#define IND_NAME "Sessions Bands (Subwindow)"

// -------------------- Inputs --------------------
extern int    DaysBack         = 20;
extern int    DaysForward      = 0;
extern double TimeOffsetHours  = 0.0;

// Placement: 0=Top, 1=Bottom, 2=Both
extern int    BandPlacement    = 1;

// Band heights as fraction of pane height (0..1)
extern double MicroBandHeightPct  = 0.05;  // 22.5M cycle band height
extern double Layer0BandHeightPct = 0.06;  // 90M cycle band height
extern double Layer1BandHeightPct = 0.06;  // Day cycle Min band height
extern double Layer2BandHeightPct = 0.06;  // Week cycle Min band height
extern double Layer3BandHeightPct = 0.06;  // Month cycle Min band height
extern double Layer4BandHeightPct = 0.06;  // Year cycle band height
extern double Layer5BandHeightPct = 0.06;  // 4 Year cycle band height

// Label baseline compensation (OBJ_TEXT anchors to baseline)
extern double LabelCenterShiftPct = 0.15;

// Timeframe checkboxes
extern bool Show_M1  = true;
extern bool Show_M5  = true;
extern bool Show_M15 = true;
extern bool Show_M30 = true;
extern bool Show_H1  = true;
extern bool Show_H4  = true;
extern bool Show_D1  = true;
extern bool Show_W1  = true;
extern bool Show_MN1 = true;

// -------------------- 22.5M cycle layer --------------------
extern bool   Micro_Enable        = true;   // 22.5M cycle enabled
extern int    MicroStepSeconds    = 1350;   // 22.5M cycle step seconds
extern int    MicroSegmentsCount  = 4;      // 22.5M cycle segments count

extern bool   Micro_ShowLabels    = false;  // 22.5M cycle show labels
extern bool   Micro_LabelShowName = true;   // 22.5M cycle label show name
extern int    Micro_LabelSize     = 8;      // 22.5M cycle label size
extern color  Micro_LabelColor    = clrBlack; // 22.5M cycle label color

// 22.5M cycle quarter definitions
extern bool   Micro_M1_Enable=true;  // 22.5M cycle Q1 enable
extern string Micro_M1_Name="22.5M cycle Q1"; // 22.5M cycle Q1 name
extern color  Micro_M1_Color=clrGainsboro;    // 22.5M cycle Q1 color

extern bool   Micro_M2_Enable=true;  // 22.5M cycle Q2 enable
extern string Micro_M2_Name="22.5M cycle Q2"; // 22.5M cycle Q2 name
extern color  Micro_M2_Color=clrSilver;       // 22.5M cycle Q2 color

extern bool   Micro_M3_Enable=true;  // 22.5M cycle Q3 enable
extern string Micro_M3_Name="22.5M cycle Q3"; // 22.5M cycle Q3 name
extern color  Micro_M3_Color=clrGainsboro;    // 22.5M cycle Q3 color

extern bool   Micro_M4_Enable=true;  // 22.5M cycle Q4 enable
extern string Micro_M4_Name="22.5M cycle Q4"; // 22.5M cycle Q4 name
extern color  Micro_M4_Color=clrSilver;       // 22.5M cycle Q4 color

// -------------------- 90M cycle layer --------------------
extern bool   L0_Enable = true; // 90M cycle enabled

extern bool   L0_S1_Enable=true;   // 90M cycle Q1 enable
extern string L0_S1_Name="90M cycle Q1"; // 90M cycle Q1 name
extern string L0_S1_Start="04:00"; // 90M cycle Q1 start
extern string L0_S1_End="05:30";   // 90M cycle Q1 end
extern color  L0_S1_Color=Silver;  // 90M cycle Q1 color

extern bool   L0_S2_Enable=true;   // 90M cycle Q2 enable
extern string L0_S2_Name="90M cycle Q2"; // 90M cycle Q2 name
extern string L0_S2_Start="05:30"; // 90M cycle Q2 start
extern string L0_S2_End="07:00";   // 90M cycle Q2 end
extern color  L0_S2_Color=Silver;  // 90M cycle Q2 color

extern bool   L0_S3_Enable=true;   // 90M cycle Q3 enable
extern string L0_S3_Name="90M cycle Q3"; // 90M cycle Q3 name
extern string L0_S3_Start="07:00"; // 90M cycle Q3 start
extern string L0_S3_End="08:30";   // 90M cycle Q3 end
extern color  L0_S3_Color=Silver;  // 90M cycle Q3 color

extern bool   L0_S4_Enable=true;   // 90M cycle Q4 enable
extern string L0_S4_Name="90M cycle Q4"; // 90M cycle Q4 name
extern string L0_S4_Start="08:30"; // 90M cycle Q4 start
extern string L0_S4_End="10:00";   // 90M cycle Q4 end
extern color  L0_S4_Color=Silver;  // 90M cycle Q4 color

extern bool   L0_S5_Enable=true;   // 90M cycle Q5 enable
extern string L0_S5_Name="90M cycle Q5"; // 90M cycle Q5 name
extern string L0_S5_Start="10:00"; // 90M cycle Q5 start
extern string L0_S5_End="11:30";   // 90M cycle Q5 end
extern color  L0_S5_Color=Silver;  // 90M cycle Q5 color

extern bool   L0_S6_Enable=true;   // 90M cycle Q6 enable
extern string L0_S6_Name="90M cycle Q6"; // 90M cycle Q6 name
extern string L0_S6_Start="11:30"; // 90M cycle Q6 start
extern string L0_S6_End="13:00";   // 90M cycle Q6 end
extern color  L0_S6_Color=Silver;  // 90M cycle Q6 color

extern bool   L0_S7_Enable=true;   // 90M cycle Q7 enable
extern string L0_S7_Name="90M cycle Q7"; // 90M cycle Q7 name
extern string L0_S7_Start="13:00"; // 90M cycle Q7 start
extern string L0_S7_End="14:30";   // 90M cycle Q7 end
extern color  L0_S7_Color=Silver;  // 90M cycle Q7 color

extern bool   L0_S8_Enable=true;   // 90M cycle Q8 enable
extern string L0_S8_Name="90M cycle Q8"; // 90M cycle Q8 name
extern string L0_S8_Start="14:30"; // 90M cycle Q8 start
extern string L0_S8_End="16:00";   // 90M cycle Q8 end
extern color  L0_S8_Color=Silver;  // 90M cycle Q8 color

extern bool   L0_S9_Enable=true;   // 90M cycle Q9 enable
extern string L0_S9_Name="90M cycle Q9"; // 90M cycle Q9 name
extern string L0_S9_Start="16:00"; // 90M cycle Q9 start
extern string L0_S9_End="17:30";   // 90M cycle Q9 end
extern color  L0_S9_Color=Silver;  // 90M cycle Q9 color

extern bool   L0_S10_Enable=true;   // 90M cycle Q10 enable
extern string L0_S10_Name="90M cycle Q10"; // 90M cycle Q10 name
extern string L0_S10_Start="17:30"; // 90M cycle Q10 start
extern string L0_S10_End="19:00";   // 90M cycle Q10 end
extern color  L0_S10_Color=Silver;  // 90M cycle Q10 color

extern bool   L0_S11_Enable=true;   // 90M cycle Q11 enable
extern string L0_S11_Name="90M cycle Q11"; // 90M cycle Q11 name
extern string L0_S11_Start="19:00"; // 90M cycle Q11 start
extern string L0_S11_End="20:30";   // 90M cycle Q11 end
extern color  L0_S11_Color=Silver;  // 90M cycle Q11 color

extern bool   L0_S12_Enable=true;   // 90M cycle Q12 enable
extern string L0_S12_Name="90M cycle Q12"; // 90M cycle Q12 name
extern string L0_S12_Start="20:30"; // 90M cycle Q12 start
extern string L0_S12_End="22:00";   // 90M cycle Q12 end
extern color  L0_S12_Color=Silver;  // 90M cycle Q12 color

extern bool   L0_S13_Enable=true;   // 90M cycle Q13 enable
extern string L0_S13_Name="90M cycle Q13"; // 90M cycle Q13 name
extern string L0_S13_Start="22:00"; // 90M cycle Q13 start
extern string L0_S13_End="23:30";   // 90M cycle Q13 end
extern color  L0_S13_Color=Silver;  // 90M cycle Q13 color

extern bool   L0_S14_Enable=true;   // 90M cycle Q14 enable
extern string L0_S14_Name="90M cycle Q14"; // 90M cycle Q14 name
extern string L0_S14_Start="23:30"; // 90M cycle Q14 start
extern string L0_S14_End="01:00";   // 90M cycle Q14 end
extern color  L0_S14_Color=Silver;  // 90M cycle Q14 color

extern bool   L0_S15_Enable=true;   // 90M cycle Q15 enable
extern string L0_S15_Name="90M cycle Q15"; // 90M cycle Q15 name
extern string L0_S15_Start="01:00"; // 90M cycle Q15 start
extern string L0_S15_End="02:30";   // 90M cycle Q15 end
extern color  L0_S15_Color=Silver;  // 90M cycle Q15 color

extern bool   L0_S16_Enable=true;   // 90M cycle Q16 enable
extern string L0_S16_Name="90M cycle Q16"; // 90M cycle Q16 name
extern string L0_S16_Start="02:30"; // 90M cycle Q16 start
extern string L0_S16_End="04:00";   // 90M cycle Q16 end
extern color  L0_S16_Color=Silver;  // 90M cycle Q16 color

// -------------------- Day cycle layer --------------------
extern bool   L1_S1_Enable = true;       // Day cycle Q1 enable
extern string L1_S1_Name   = "Day cycle Q1"; // Day cycle Q1 name
extern string L1_S1_Start  = "00:00";    // Day cycle Q1 start
extern string L1_S1_End    = "08:00";    // Day cycle Q1 end
extern color  L1_S1_Color  = DeepSkyBlue; // Day cycle Q1 color

extern bool   L1_S2_Enable = true;       // Day cycle Q2 enable
extern string L1_S2_Name   = "Day cycle Q2"; // Day cycle Q2 name
extern string L1_S2_Start  = "08:00";    // Day cycle Q2 start
extern string L1_S2_End    = "16:00";    // Day cycle Q2 end
extern color  L1_S2_Color  = MediumSeaGreen; // Day cycle Q2 color

extern bool   L1_S3_Enable = true;       // Day cycle Q3 enable
extern string L1_S3_Name   = "Day cycle Q3"; // Day cycle Q3 name
extern string L1_S3_Start  = "13:00";    // Day cycle Q3 start
extern string L1_S3_End    = "21:00";    // Day cycle Q3 end
extern color  L1_S3_Color  = Tomato;     // Day cycle Q3 color

extern bool   L1_S4_Enable = false;      // Day cycle Q4 enable
extern string L1_S4_Name   = "Day cycle Q4"; // Day cycle Q4 name
extern string L1_S4_Start  = "21:00";    // Day cycle Q4 start
extern string L1_S4_End    = "05:00";    // Day cycle Q4 end
extern color  L1_S4_Color  = Orchid;     // Day cycle Q4 color

// -------------------- Week cycle layer --------------------
extern bool   L2_Enable = false; // Week cycle enabled
// DOW input accepted formats:
//  - 0=Sunday, 1=Monday, ... 6=Saturday
//  - 1=Monday, 2=Tuesday, ... 7=Sunday
extern bool   L2_S1_Enable = false;         // Week cycle Q1 enable
extern string L2_S1_Name="Week cycle Q1";   // Week cycle Q1 name
extern int    L2_S1_StartDOW=1;             // Week cycle Q1 start DOW
extern string L2_S1_Start="00:00";          // Week cycle Q1 start
extern int    L2_S1_EndDOW=5;               // Week cycle Q1 end DOW
extern string L2_S1_End="23:59";            // Week cycle Q1 end
extern color  L2_S1_Color=Gainsboro;        // Week cycle Q1 color

extern bool   L2_S2_Enable = false;         // Week cycle Q2 enable
extern string L2_S2_Name="Week cycle Q2";   // Week cycle Q2 name
extern int    L2_S2_StartDOW=0;             // Week cycle Q2 start DOW
extern string L2_S2_Start="00:00";          // Week cycle Q2 start
extern int    L2_S2_EndDOW=0;               // Week cycle Q2 end DOW
extern string L2_S2_End="06:00";            // Week cycle Q2 end
extern color  L2_S2_Color=Gainsboro;        // Week cycle Q2 color

extern bool   L2_S3_Enable = false;         // Week cycle Q3 enable
extern string L2_S3_Name="Week cycle Q3";   // Week cycle Q3 name
extern int    L2_S3_StartDOW=0;             // Week cycle Q3 start DOW
extern string L2_S3_Start="00:00";          // Week cycle Q3 start
extern int    L2_S3_EndDOW=0;               // Week cycle Q3 end DOW
extern string L2_S3_End="06:00";            // Week cycle Q3 end
extern color  L2_S3_Color=Gainsboro;        // Week cycle Q3 color

extern bool   L2_S4_Enable = false;         // Week cycle Q4 enable
extern string L2_S4_Name="Week cycle Q4";   // Week cycle Q4 name
extern int    L2_S4_StartDOW=0;             // Week cycle Q4 start DOW
extern string L2_S4_Start="00:00";          // Week cycle Q4 start
extern int    L2_S4_EndDOW=0;               // Week cycle Q4 end DOW
extern string L2_S4_End="06:00";            // Week cycle Q4 end
extern color  L2_S4_Color=Gainsboro;        // Week cycle Q4 color

// -------------------- Month cycle layer --------------------
extern bool   L3_Enable = true; // Month cycle enabled

extern string L3_W1_Name  = "Month cycle Q1"; // Month cycle Q1 name
extern string L3_W2_Name  = "Month cycle Q2"; // Month cycle Q2 name
extern string L3_W3_Name  = "Month cycle Q3"; // Month cycle Q3 name
extern string L3_W4_Name  = "Month cycle Q4"; // Month cycle Q4 name

extern color  L3_W1_Color = LightSlateGray; // Month cycle Q1 color
extern color  L3_W2_Color = Maroon;         // Month cycle Q2 color
extern color  L3_W3_Color = DarkGreen;      // Month cycle Q3 color
extern color  L3_W4_Color = MidnightBlue;   // Month cycle Q4 color

// choose week anchor for month start
extern int    Month_cycle_start_DOW  = 2;
extern string Month_cycle_start_HHMM = "04:00";

// -------------------- Year cycle layer --------------------
extern bool   YEAR_cycle_enable      = true;            // YEAR cycle enable
extern int    Year_Cycle_Start_Month = 4;               // Year Cycle Start Month
extern int    Year_Cycle_Start_Day   = 1;               // Year Cycle Start Day
extern string Year_Label_Prefix      = "Y Q";           // Year Label Prefix

extern color  YEAR_cycle_Q1_color    = LightSlateGray;  // YEAR cycle Q1 color
extern color  YEAR_cycle_Q2_color    = Maroon;          // YEAR cycle Q2 color
extern color  YEAR_cycle_Q3_color    = DarkGreen;       // YEAR cycle Q3 color
extern color  YEAR_cycle_Q4_color    = MidnightBlue;    // YEAR cycle Q4 color

// -------------------- 4 Year cycle layer --------------------
extern bool   Four_Year_Cycle_Enable   = true;             // 4 Year Cycle Enable
extern string Four_Year_Cycle_Start    = "2025.04.01";     // YYYY.MM.DD (cycle start)

extern string Four_Year_Cycle_Q1_name  = "4Y-Q1-A";        // 4 Year Cycle Q1 name
extern string Four_Year_Cycle_Q2_name  = "4Y-Q2-M";        // 4 Year Cycle Q2 name
extern string Four_Year_Cycle_Q3_name  = "4Y-Q3-D";        // 4 Year Cycle Q3 name
extern string Four_Year_Cycle_Q4_name  = "4Y-Q4-X";        // 4 Year Cycle Q4 name

extern color  Four_Year_Cycle_Q1_Color = LightSlateGray;   // 4 Year Cycle Q1 Color
extern color  Four_Year_Cycle_Q2_Color = Maroon;           // 4 Year Cycle Q2 Color
extern color  Four_Year_Cycle_Q3_Color = DarkGreen;        // 4 Year Cycle Q3 Color
extern color  Four_Year_Cycle_Q4_Color = MidnightBlue;     // 4 Year Cycle Q4 Color

// -------------------- Visual --------------------
extern int    RectBorderWidth = 1;
extern bool   RectBehind      = true;

// Labels (global)
extern bool   ShowSessionLabels = true;
extern int    SessionLabelSize  = 9;
extern color  SessionLabelColor = Black;

// -------------------- Internal --------------------
double bufMin[];
double bufMax[];

// prefixes
string PREFIX_RECT_MICRO = "SessMicroBand_";
string PREFIX_LBL_MICRO  = "SessMicroLbl_";

string PREFIX_RECT_L0 = "Sess0Band_";
string PREFIX_LBL_L0  = "Sess0Lbl_";

string PREFIX_RECT_L1 = "Sess1Band_";
string PREFIX_LBL_L1  = "Sess1Lbl_";
string PREFIX_RECT_L2 = "Sess2Band_";
string PREFIX_LBL_L2  = "Sess2Lbl_";
string PREFIX_RECT_L3 = "Sess3Band_";
string PREFIX_LBL_L3  = "Sess3Lbl_";
string PREFIX_RECT_L4 = "Sess4Band_";
string PREFIX_LBL_L4  = "Sess4Lbl_";
string PREFIX_RECT_L5 = "Sess5Band_";
string PREFIX_LBL_L5  = "Sess5Lbl_";

string SIDE_BOTTOM = "_B_";
string SIDE_TOP    = "_T_";

struct SessionDef { bool enable; string name; string start; string end; color col; };
struct SpanDef    { bool enable; string name; int startDOW; string start; int endDOW; string end; color col; };
struct MicroDef   { bool enable; string name; color col; };

SessionDef sessions0[16];
SessionDef sessions1[4];
SpanDef    sessions2[4];
MicroDef   microDefs[4];

int g_win = -1;

// runtime state
datetime g_lastBarTime      = 0;
int      g_lastPeriod       = 0;
int      g_lastPlacement    = -999999;
int      g_lastBars         = 0;
bool     g_firstStart       = true;
bool     g_tfObjectsDeleted = false;

// layer ids
#define LAYER_MICRO 0
#define LAYER_90M   1
#define LAYER_L1    2
#define LAYER_L2    3
#define LAYER_L3    4
#define LAYER_L4    5
#define LAYER_L5    6

// -------------------- Helpers --------------------
bool TimeframeAllowed()
{
   int tf = Period();
   if(tf==PERIOD_M1)  return Show_M1;
   if(tf==PERIOD_M5)  return Show_M5;
   if(tf==PERIOD_M15) return Show_M15;
   if(tf==PERIOD_M30) return Show_M30;
   if(tf==PERIOD_H1)  return Show_H1;
   if(tf==PERIOD_H4)  return Show_H4;
   if(tf==PERIOD_D1)  return Show_D1;
   if(tf==PERIOD_W1)  return Show_W1;
   if(tf==PERIOD_MN1) return Show_MN1;
   return true;
}

bool ParseHHMM(string hhmm, int &hh, int &mm)
{
   int p = StringFind(hhmm, ":");
   if(p < 0) return false;
   hh = StrToInteger(StringSubstr(hhmm, 0, p));
   mm = StrToInteger(StringSubstr(hhmm, p + 1));
   return (hh>=0 && hh<=23 && mm>=0 && mm<=59);
}

datetime DayStart(datetime t) { return (datetime)(t - (t % 86400)); }

bool WantBottom() { return (BandPlacement == 1 || BandPlacement == 2); }
bool WantTop()    { return (BandPlacement == 0 || BandPlacement == 2); }

// Accept both:
//  0=Sun..6=Sat
//  1=Mon..7=Sun
bool NormalizeDOWInput(int inDOW, int &outDOW)
{
   if(inDOW >= 0 && inDOW <= 6)
   {
      outDOW = inDOW;
      return true;
   }

   if(inDOW >= 1 && inDOW <= 7)
   {
      if(inDOW == 7) outDOW = 0;
      else           outDOW = inDOW;
      return true;
   }

   return false;
}

void DeleteByPrefix(string pref)
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, pref) == 0)
         ObjectDelete(name);
   }
}

void DeleteByPrefixAndSide(string pref, string sideTag)
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, pref) == 0 && StringFind(name, sideTag) >= 0)
         ObjectDelete(name);
   }
}

void DeleteAllIndicatorObjects()
{
   DeleteByPrefix(PREFIX_RECT_MICRO); DeleteByPrefix(PREFIX_LBL_MICRO);
   DeleteByPrefix(PREFIX_RECT_L0);    DeleteByPrefix(PREFIX_LBL_L0);
   DeleteByPrefix(PREFIX_RECT_L1);    DeleteByPrefix(PREFIX_LBL_L1);
   DeleteByPrefix(PREFIX_RECT_L2);    DeleteByPrefix(PREFIX_LBL_L2);
   DeleteByPrefix(PREFIX_RECT_L3);    DeleteByPrefix(PREFIX_LBL_L3);
   DeleteByPrefix(PREFIX_RECT_L4);    DeleteByPrefix(PREFIX_LBL_L4);
   DeleteByPrefix(PREFIX_RECT_L5);    DeleteByPrefix(PREFIX_LBL_L5);
}

// -------------------- Date helpers --------------------
bool IsLeapYear(int y)
{
   if((y % 400) == 0) return true;
   if((y % 100) == 0) return false;
   return ((y % 4) == 0);
}

int DaysInMonth(int y, int m)
{
   if(m==1 || m==3 || m==5 || m==7 || m==8 || m==10 || m==12) return 31;
   if(m==4 || m==6 || m==9 || m==11) return 30;
   if(m==2) return IsLeapYear(y) ? 29 : 28;
   return 30;
}

datetime MakeDateTimeSafe(int y, int m, int d, int hh=0, int mm=0, int ss=0)
{
   while(m > 12) { m -= 12; y++; }
   while(m < 1)  { m += 12; y--; }

   int dim = DaysInMonth(y, m);
   if(d < 1) d = 1;
   if(d > dim) d = dim;

   string ys  = IntegerToString(y);
   string ms  = (m < 10 ? "0" : "") + IntegerToString(m);
   string ds  = (d < 10 ? "0" : "") + IntegerToString(d);
   string hs  = (hh < 10 ? "0" : "") + IntegerToString(hh);
   string mis = (mm < 10 ? "0" : "") + IntegerToString(mm);
   string sss = (ss < 10 ? "0" : "") + IntegerToString(ss);

   return StrToTime(ys + "." + ms + "." + ds + " " + hs + ":" + mis + ":" + sss);
}

datetime AddMonthsKeepDay(datetime t, int addMonths)
{
   int y  = TimeYear(t);
   int m  = TimeMonth(t);
   int d  = TimeDay(t);
   int hh = TimeHour(t);
   int mm = TimeMinute(t);
   int ss = TimeSeconds(t);

   m += addMonths;
   while(m > 12) { m -= 12; y++; }
   while(m < 1)  { m += 12; y--; }

   return MakeDateTimeSafe(y, m, d, hh, mm, ss);
}

datetime AddYearsKeepDate(datetime t, int addYears)
{
   int y  = TimeYear(t) + addYears;
   int m  = TimeMonth(t);
   int d  = TimeDay(t);
   int hh = TimeHour(t);
   int mm = TimeMinute(t);
   int ss = TimeSeconds(t);

   return MakeDateTimeSafe(y, m, d, hh, mm, ss);
}

bool ParseYYYYMMDD(string s, int &y, int &m, int &d)
{
   string t = s;
   StringReplace(t, "-", ".");
   int p1 = StringFind(t, ".");
   if(p1 < 0) return false;
   int p2 = StringFind(t, ".", p1 + 1);
   if(p2 < 0) return false;

   y = StrToInteger(StringSubstr(t, 0, p1));
   m = StrToInteger(StringSubstr(t, p1 + 1, p2 - p1 - 1));
   d = StrToInteger(StringSubstr(t, p2 + 1));

   if(y < 1900 || m < 1 || m > 12 || d < 1 || d > 31) return false;
   return true;
}

string IntTo2(int v)
{
   if(v < 10) return "0" + IntegerToString(v);
   return IntegerToString(v);
}

string DateStamp(datetime t)
{
   return IntegerToString(TimeYear(t)) + IntTo2(TimeMonth(t)) + IntTo2(TimeDay(t));
}

// -------------------- Naming --------------------
string RectNameSpan(string prefix, string side, datetime d0, int idx)
{  return prefix + side + IntegerToString(idx) + "_" + TimeToStr(d0, TIME_DATE); }

string LabelNameSpan(string prefix, string side, datetime d0, int idx)
{  return prefix + side + IntegerToString(idx) + "_" + TimeToStr(d0, TIME_DATE); }

string RectNameL1(string prefix, string side, datetime d0, int idx, int part)
{  return prefix + side + IntegerToString(idx) + "_" + IntegerToString(part) + "_" + TimeToStr(d0, TIME_DATE); }

string LabelNameL1(string prefix, string side, datetime d0, int idx, int part)
{  return prefix + side + IntegerToString(idx) + "_" + IntegerToString(part) + "_" + TimeToStr(d0, TIME_DATE); }

// 22.5M cycle names
string RectNameMicro(string side, datetime d0, int slotIdx, int microIdx)
{  return PREFIX_RECT_MICRO + side + IntegerToString(slotIdx) + "_q" + IntegerToString(microIdx+1) + "_" + TimeToStr(d0, TIME_DATE); }

string LabelNameMicro(string side, datetime d0, int slotIdx, int microIdx)
{  return PREFIX_LBL_MICRO + side + IntegerToString(slotIdx) + "_q" + IntegerToString(microIdx+1) + "_" + TimeToStr(d0, TIME_DATE); }

// generic period names
string RectNamePeriod(string prefix, string side, datetime periodStart)
{  return prefix + side + DateStamp(periodStart); }

string LabelNamePeriod(string prefix, string side, datetime periodStart)
{  return prefix + side + DateStamp(periodStart); }

// -------------------- Fixed pane Y geometry (0..1) --------------------
double Clamp01(double v){ if(v<0) return 0; if(v>1) return 1; return v; }

void GetBandPricesLayer(int layer, int place, double &pBottom, double &pTop, double &pTextY)
{
   double hM = MicroBandHeightPct;
   double h0 = Layer0BandHeightPct;
   double h1 = Layer1BandHeightPct;
   double h2 = Layer2BandHeightPct;
   double h3 = Layer3BandHeightPct;
   double h4 = Layer4BandHeightPct;
   double h5 = Layer5BandHeightPct;

   if(hM<0) hM=0; if(h0<0) h0=0; if(h1<0) h1=0; if(h2<0) h2=0; if(h3<0) h3=0; if(h4<0) h4=0; if(h5<0) h5=0;

   double base=0, h=0;

   if(place == 1) // bottom
   {
      if(layer == LAYER_L5)    { base = 0.0;                          h = h5; }
      if(layer == LAYER_L4)    { base = 0.0 + h5;                     h = h4; }
      if(layer == LAYER_L3)    { base = 0.0 + h5 + h4;                h = h3; }
      if(layer == LAYER_L2)    { base = 0.0 + h5 + h4 + h3;           h = h2; }
      if(layer == LAYER_L1)    { base = 0.0 + h5 + h4 + h3 + h2;      h = h1; }
      if(layer == LAYER_90M)   { base = 0.0 + h5 + h4 + h3 + h2 + h1; h = h0; }
      if(layer == LAYER_MICRO) { base = 0.0 + h5 + h4 + h3 + h2 + h1 + h0; h = hM; }
   }
   else // top
   {
      if(layer == LAYER_MICRO) { base = 1.0 - hM;                           h = hM; }
      if(layer == LAYER_90M)   { base = 1.0 - hM - h0;                      h = h0; }
      if(layer == LAYER_L1)    { base = 1.0 - hM - h0 - h1;                 h = h1; }
      if(layer == LAYER_L2)    { base = 1.0 - hM - h0 - h1 - h2;            h = h2; }
      if(layer == LAYER_L3)    { base = 1.0 - hM - h0 - h1 - h2 - h3;       h = h3; }
      if(layer == LAYER_L4)    { base = 1.0 - hM - h0 - h1 - h2 - h3 - h4;  h = h4; }
      if(layer == LAYER_L5)    { base = 1.0 - hM - h0 - h1 - h2 - h3 - h4 - h5; h = h5; }
   }

   pBottom = Clamp01(base);
   pTop    = Clamp01(base + h);

   double mid = pBottom + (pTop - pBottom)/2.0;
   double hh  = (pTop - pBottom);
   pTextY = Clamp01(mid - (hh * LabelCenterShiftPct));
}

// -------------------- Subwindow index --------------------
void EnsureWindowIndex()
{
   if(g_win >= 0) return;
   g_win = WindowFind(IND_NAME);
   if(g_win < 0) g_win = 1;
}

// -------------------- Objects --------------------
void CreateSessionRectLayer(int layer, int place, string name, datetime t1, datetime t2, color c)
{
   EnsureWindowIndex();

   double pB, pT, pTextY;
   GetBandPricesLayer(layer, place, pB, pT, pTextY);

   if(ObjectFind(name) < 0)
   {
      ObjectCreate(name, OBJ_RECTANGLE, g_win, t1, pB, t2, pT);
      ObjectSet(name, OBJPROP_COLOR, c);
      ObjectSet(name, OBJPROP_WIDTH, RectBorderWidth);
      ObjectSet(name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(name, OBJPROP_BACK, RectBehind);
      ObjectSet(name, OBJPROP_SELECTABLE, false);
   }
}

void CreateTextLabelLayer(int layer, int place, string name, datetime t1, datetime t2, string text, int fontSize, color fontColor)
{
   EnsureWindowIndex();

   double pB, pT, pTextY;
   GetBandPricesLayer(layer, place, pB, pT, pTextY);

   datetime midT = t1 + (t2 - t1) / 2;

   if(ObjectFind(name) < 0)
   {
      ObjectCreate(name, OBJ_TEXT, g_win, midT, pTextY);
      ObjectSetText(name, text, fontSize, "Arial", fontColor);
      ObjectSet(name, OBJPROP_BACK, true);
      ObjectSet(name, OBJPROP_SELECTABLE, false);
   }
}

void CreateSessionLabelGlobal(int layer, int place, string name, datetime t1, datetime t2, string text)
{
   if(!ShowSessionLabels) return;
   CreateTextLabelLayer(layer, place, name, t1, t2, text, SessionLabelSize, SessionLabelColor);
}

// -------------------- Placement cleanup --------------------
void CleanupPlacementObjects()
{
   if(BandPlacement == 0)
   {
      DeleteByPrefixAndSide(PREFIX_RECT_MICRO, SIDE_BOTTOM);
      DeleteByPrefixAndSide(PREFIX_LBL_MICRO,  SIDE_BOTTOM);

      DeleteByPrefixAndSide(PREFIX_RECT_L0, SIDE_BOTTOM);
      DeleteByPrefixAndSide(PREFIX_LBL_L0,  SIDE_BOTTOM);

      DeleteByPrefixAndSide(PREFIX_RECT_L1, SIDE_BOTTOM);
      DeleteByPrefixAndSide(PREFIX_LBL_L1,  SIDE_BOTTOM);

      DeleteByPrefixAndSide(PREFIX_RECT_L2, SIDE_BOTTOM);
      DeleteByPrefixAndSide(PREFIX_LBL_L2,  SIDE_BOTTOM);

      DeleteByPrefixAndSide(PREFIX_RECT_L3, SIDE_BOTTOM);
      DeleteByPrefixAndSide(PREFIX_LBL_L3,  SIDE_BOTTOM);

      DeleteByPrefixAndSide(PREFIX_RECT_L4, SIDE_BOTTOM);
      DeleteByPrefixAndSide(PREFIX_LBL_L4,  SIDE_BOTTOM);

      DeleteByPrefixAndSide(PREFIX_RECT_L5, SIDE_BOTTOM);
      DeleteByPrefixAndSide(PREFIX_LBL_L5,  SIDE_BOTTOM);
   }
   else if(BandPlacement == 1)
   {
      DeleteByPrefixAndSide(PREFIX_RECT_MICRO, SIDE_TOP);
      DeleteByPrefixAndSide(PREFIX_LBL_MICRO,  SIDE_TOP);

      DeleteByPrefixAndSide(PREFIX_RECT_L0, SIDE_TOP);
      DeleteByPrefixAndSide(PREFIX_LBL_L0,  SIDE_TOP);

      DeleteByPrefixAndSide(PREFIX_RECT_L1, SIDE_TOP);
      DeleteByPrefixAndSide(PREFIX_LBL_L1,  SIDE_TOP);

      DeleteByPrefixAndSide(PREFIX_RECT_L2, SIDE_TOP);
      DeleteByPrefixAndSide(PREFIX_LBL_L2,  SIDE_TOP);

      DeleteByPrefixAndSide(PREFIX_RECT_L3, SIDE_TOP);
      DeleteByPrefixAndSide(PREFIX_LBL_L3,  SIDE_TOP);

      DeleteByPrefixAndSide(PREFIX_RECT_L4, SIDE_TOP);
      DeleteByPrefixAndSide(PREFIX_LBL_L4,  SIDE_TOP);

      DeleteByPrefixAndSide(PREFIX_RECT_L5, SIDE_TOP);
      DeleteByPrefixAndSide(PREFIX_LBL_L5,  SIDE_TOP);
   }
}

// -------------------- Refresh inputs into arrays --------------------
void RefreshInputsToArrays()
{
   microDefs[0].enable = Micro_M1_Enable; microDefs[0].name = Micro_M1_Name; microDefs[0].col = Micro_M1_Color;
   microDefs[1].enable = Micro_M2_Enable; microDefs[1].name = Micro_M2_Name; microDefs[1].col = Micro_M2_Color;
   microDefs[2].enable = Micro_M3_Enable; microDefs[2].name = Micro_M3_Name; microDefs[2].col = Micro_M3_Color;
   microDefs[3].enable = Micro_M4_Enable; microDefs[3].name = Micro_M4_Name; microDefs[3].col = Micro_M4_Color;

   sessions0[0].enable=L0_S1_Enable;   sessions0[0].name=L0_S1_Name;   sessions0[0].start=L0_S1_Start;   sessions0[0].end=L0_S1_End;   sessions0[0].col=L0_S1_Color;
   sessions0[1].enable=L0_S2_Enable;   sessions0[1].name=L0_S2_Name;   sessions0[1].start=L0_S2_Start;   sessions0[1].end=L0_S2_End;   sessions0[1].col=L0_S2_Color;
   sessions0[2].enable=L0_S3_Enable;   sessions0[2].name=L0_S3_Name;   sessions0[2].start=L0_S3_Start;   sessions0[2].end=L0_S3_End;   sessions0[2].col=L0_S3_Color;
   sessions0[3].enable=L0_S4_Enable;   sessions0[3].name=L0_S4_Name;   sessions0[3].start=L0_S4_Start;   sessions0[3].end=L0_S4_End;   sessions0[3].col=L0_S4_Color;

   sessions0[4].enable=L0_S5_Enable;   sessions0[4].name=L0_S5_Name;   sessions0[4].start=L0_S5_Start;   sessions0[4].end=L0_S5_End;   sessions0[4].col=L0_S5_Color;
   sessions0[5].enable=L0_S6_Enable;   sessions0[5].name=L0_S6_Name;   sessions0[5].start=L0_S6_Start;   sessions0[5].end=L0_S6_End;   sessions0[5].col=L0_S6_Color;
   sessions0[6].enable=L0_S7_Enable;   sessions0[6].name=L0_S7_Name;   sessions0[6].start=L0_S7_Start;   sessions0[6].end=L0_S7_End;   sessions0[6].col=L0_S7_Color;
   sessions0[7].enable=L0_S8_Enable;   sessions0[7].name=L0_S8_Name;   sessions0[7].start=L0_S8_Start;   sessions0[7].end=L0_S8_End;   sessions0[7].col=L0_S8_Color;

   sessions0[8].enable=L0_S9_Enable;   sessions0[8].name=L0_S9_Name;   sessions0[8].start=L0_S9_Start;   sessions0[8].end=L0_S9_End;   sessions0[8].col=L0_S9_Color;
   sessions0[9].enable=L0_S10_Enable;  sessions0[9].name=L0_S10_Name;  sessions0[9].start=L0_S10_Start;  sessions0[9].end=L0_S10_End;  sessions0[9].col=L0_S10_Color;
   sessions0[10].enable=L0_S11_Enable; sessions0[10].name=L0_S11_Name; sessions0[10].start=L0_S11_Start; sessions0[10].end=L0_S11_End; sessions0[10].col=L0_S11_Color;
   sessions0[11].enable=L0_S12_Enable; sessions0[11].name=L0_S12_Name; sessions0[11].start=L0_S12_Start; sessions0[11].end=L0_S12_End; sessions0[11].col=L0_S12_Color;

   sessions0[12].enable=L0_S13_Enable; sessions0[12].name=L0_S13_Name; sessions0[12].start=L0_S13_Start; sessions0[12].end=L0_S13_End; sessions0[12].col=L0_S13_Color;
   sessions0[13].enable=L0_S14_Enable; sessions0[13].name=L0_S14_Name; sessions0[13].start=L0_S14_Start; sessions0[13].end=L0_S14_End; sessions0[13].col=L0_S14_Color;
   sessions0[14].enable=L0_S15_Enable; sessions0[14].name=L0_S15_Name; sessions0[14].start=L0_S15_Start; sessions0[14].end=L0_S15_End; sessions0[14].col=L0_S15_Color;
   sessions0[15].enable=L0_S16_Enable; sessions0[15].name=L0_S16_Name; sessions0[15].start=L0_S16_Start; sessions0[15].end=L0_S16_End; sessions0[15].col=L0_S16_Color;

   sessions1[0].enable=L1_S1_Enable; sessions1[0].name=L1_S1_Name; sessions1[0].start=L1_S1_Start; sessions1[0].end=L1_S1_End; sessions1[0].col=L1_S1_Color;
   sessions1[1].enable=L1_S2_Enable; sessions1[1].name=L1_S2_Name; sessions1[1].start=L1_S2_Start; sessions1[1].end=L1_S2_End; sessions1[1].col=L1_S2_Color;
   sessions1[2].enable=L1_S3_Enable; sessions1[2].name=L1_S3_Name; sessions1[2].start=L1_S3_Start; sessions1[2].end=L1_S3_End; sessions1[2].col=L1_S3_Color;
   sessions1[3].enable=L1_S4_Enable; sessions1[3].name=L1_S4_Name; sessions1[3].start=L1_S4_Start; sessions1[3].end=L1_S4_End; sessions1[3].col=L1_S4_Color;

   sessions2[0].enable=L2_S1_Enable; sessions2[0].name=L2_S1_Name; sessions2[0].startDOW=L2_S1_StartDOW; sessions2[0].start=L2_S1_Start; sessions2[0].endDOW=L2_S1_EndDOW; sessions2[0].end=L2_S1_End; sessions2[0].col=L2_S1_Color;
   sessions2[1].enable=L2_S2_Enable; sessions2[1].name=L2_S2_Name; sessions2[1].startDOW=L2_S2_StartDOW; sessions2[1].start=L2_S2_Start; sessions2[1].endDOW=L2_S2_EndDOW; sessions2[1].end=L2_S2_End; sessions2[1].col=L2_S2_Color;
   sessions2[2].enable=L2_S3_Enable; sessions2[2].name=L2_S3_Name; sessions2[2].startDOW=L2_S3_StartDOW; sessions2[2].start=L2_S3_Start; sessions2[2].endDOW=L2_S3_EndDOW; sessions2[2].end=L2_S3_End; sessions2[2].col=L2_S3_Color;
   sessions2[3].enable=L2_S4_Enable; sessions2[3].name=L2_S4_Name; sessions2[3].startDOW=L2_S4_StartDOW; sessions2[3].start=L2_S4_Start; sessions2[3].endDOW=L2_S4_EndDOW; sessions2[3].end=L2_S4_End; sessions2[3].col=L2_S4_Color;
}

// ---- Rounding helper for label times (ceil to next minute) ----
datetime CeilToMinute(datetime t)
{
   int s = (int)(t % 60);
   if(s == 0) return t;
   return (datetime)(t + (60 - s));
}
string HHMM(datetime t) { return TimeToStr(t, TIME_MINUTES); }
string MicroTimeRangeText(datetime a, datetime b)
{
   datetime aa = CeilToMinute(a);
   datetime bb = CeilToMinute(b);
   return HHMM(aa) + "-" + HHMM(bb);
}

// ============================================================
// Builders
// ============================================================

void BuildMicroFor90Slot(datetime day0, int slotIdx, datetime slotStart, datetime slotEnd)
{
   if(!Micro_Enable) return;
   if(MicroStepSeconds <= 0) return;
   if(MicroSegmentsCount <= 0) return;

   if(slotEnd <= slotStart) slotEnd += 86400;

   int maxSeg = MicroSegmentsCount;
   if(maxSeg > 12) maxSeg = 12;

   bool doB = WantBottom();
   bool doT = WantTop();

   for(int m=0; m<maxSeg; m++)
   {
      if(m > 3) break;
      if(!microDefs[m].enable) continue;

      datetime a = slotStart + (m * MicroStepSeconds);
      datetime b = slotStart + ((m+1) * MicroStepSeconds);

      if(a >= slotEnd) break;
      if(b > slotEnd) b = slotEnd;

      if(doB)
      {
         string rB = RectNameMicro(SIDE_BOTTOM, day0, slotIdx, m);
         CreateSessionRectLayer(LAYER_MICRO, 1, rB, a, b, microDefs[m].col);

         if(Micro_ShowLabels)
         {
            string lB = LabelNameMicro(SIDE_BOTTOM, day0, slotIdx, m);
            string txtB = Micro_LabelShowName ? microDefs[m].name : MicroTimeRangeText(a, b);
            CreateTextLabelLayer(LAYER_MICRO, 1, lB, a, b, txtB, Micro_LabelSize, Micro_LabelColor);
         }
      }

      if(doT)
      {
         string rT = RectNameMicro(SIDE_TOP, day0, slotIdx, m);
         CreateSessionRectLayer(LAYER_MICRO, 0, rT, a, b, microDefs[m].col);

         if(Micro_ShowLabels)
         {
            string lT = LabelNameMicro(SIDE_TOP, day0, slotIdx, m);
            string txtT = Micro_LabelShowName ? microDefs[m].name : MicroTimeRangeText(a, b);
            CreateTextLabelLayer(LAYER_MICRO, 0, lT, a, b, txtT, Micro_LabelSize, Micro_LabelColor);
         }
      }
   }
}

void BuildDailyLayer(int layer, string prefRect, string prefLbl, bool layerEnable, SessionDef &arr[], int count)
{
   if(!TimeframeAllowed()) return;
   if(!layerEnable) return;

   datetime today0 = DayStart(TimeCurrent());
   int offsetMin = (int)MathRound(TimeOffsetHours * 60.0);

   bool doB = WantBottom();
   bool doT = WantTop();

   for(int d = -DaysForward; d <= DaysBack; d++)
   {
      datetime day0 = today0 - d*86400;

      for(int i=0;i<count;i++)
      {
         SessionDef s = arr[i];
         if(!s.enable) continue;

         int sh, sm, eh, em;
         if(!ParseHHMM(s.start, sh, sm)) continue;
         if(!ParseHHMM(s.end,   eh, em)) continue;

         datetime startT = day0 + (sh*60 + sm + offsetMin) * 60;
         datetime endT   = day0 + (eh*60 + em + offsetMin) * 60;

         if(endT <= startT)
         {
            if(doB)
            {
               string r0B = RectNameL1(prefRect, SIDE_BOTTOM, day0, i, 0);
               string l0B = LabelNameL1(prefLbl,  SIDE_BOTTOM, day0, i, 0);
               CreateSessionRectLayer(layer, 1, r0B, startT, day0+86400, s.col);
               CreateSessionLabelGlobal(layer, 1, l0B, startT, day0+86400, s.name);

               string r1B = RectNameL1(prefRect, SIDE_BOTTOM, day0, i, 1);
               string l1B = LabelNameL1(prefLbl,  SIDE_BOTTOM, day0, i, 1);
               CreateSessionRectLayer(layer, 1, r1B, day0+86400, endT+86400, s.col);
               CreateSessionLabelGlobal(layer, 1, l1B, day0+86400, endT+86400, s.name);
            }
            if(doT)
            {
               string r0T = RectNameL1(prefRect, SIDE_TOP, day0, i, 0);
               string l0T = LabelNameL1(prefLbl,  SIDE_TOP, day0, i, 0);
               CreateSessionRectLayer(layer, 0, r0T, startT, day0+86400, s.col);
               CreateSessionLabelGlobal(layer, 0, l0T, startT, day0+86400, s.name);

               string r1T = RectNameL1(prefRect, SIDE_TOP, day0, i, 1);
               string l1T = LabelNameL1(prefLbl,  SIDE_TOP, day0, i, 1);
               CreateSessionRectLayer(layer, 0, r1T, day0+86400, endT+86400, s.col);
               CreateSessionLabelGlobal(layer, 0, l1T, day0+86400, endT+86400, s.name);
            }
         }
         else
         {
            if(doB)
            {
               string rB = RectNameL1(prefRect, SIDE_BOTTOM, day0, i, 0);
               string lB = LabelNameL1(prefLbl,  SIDE_BOTTOM, day0, i, 0);
               CreateSessionRectLayer(layer, 1, rB, startT, endT, s.col);
               CreateSessionLabelGlobal(layer, 1, lB, startT, endT, s.name);
            }
            if(doT)
            {
               string rT = RectNameL1(prefRect, SIDE_TOP, day0, i, 0);
               string lT = LabelNameL1(prefLbl,  SIDE_TOP, day0, i, 0);
               CreateSessionRectLayer(layer, 0, rT, startT, endT, s.col);
               CreateSessionLabelGlobal(layer, 0, lT, startT, endT, s.name);
            }
         }
      }
   }
}

void BuildLayer1()
{
   BuildDailyLayer(LAYER_L1, PREFIX_RECT_L1, PREFIX_LBL_L1, true, sessions1, 4);
}

void BuildSpanLayer(int layer, string prefRect, string prefLbl, bool layerEnable, SpanDef &arr[], int count)
{
   if(!TimeframeAllowed()) return;
   if(!layerEnable) return;

   datetime today0 = DayStart(TimeCurrent());
   int offsetMin = (int)MathRound(TimeOffsetHours * 60.0);

   bool doB = WantBottom();
   bool doT = WantTop();

   for(int d = -DaysForward; d <= DaysBack; d++)
   {
      datetime day0 = today0 - d*86400;
      int dow = TimeDayOfWeek(day0);

      for(int i=0;i<count;i++)
      {
         SpanDef s = arr[i];
         if(!s.enable) continue;

         int normStartDOW, normEndDOW;
         if(!NormalizeDOWInput(s.startDOW, normStartDOW)) continue;
         if(!NormalizeDOWInput(s.endDOW,   normEndDOW))   continue;

         if(dow != normStartDOW) continue;

         int sh, sm, eh, em;
         if(!ParseHHMM(s.start, sh, sm)) continue;
         if(!ParseHHMM(s.end,   eh, em)) continue;

         int startMin = sh*60 + sm;
         int endMin   = eh*60 + em;

         datetime startT = day0 + (startMin + offsetMin) * 60;

         int daysAhead = (normEndDOW - normStartDOW + 7) % 7;
         if(daysAhead == 0 && endMin <= startMin) daysAhead = 1;

         datetime endDay0 = day0 + daysAhead * 86400;
         datetime endT    = endDay0 + (endMin + offsetMin) * 60;

         if(endT <= startT) endT = startT + 60;

         if(doB)
         {
            string rB = RectNameSpan(prefRect, SIDE_BOTTOM, day0, i);
            string lB = LabelNameSpan(prefLbl,  SIDE_BOTTOM, day0, i);
            CreateSessionRectLayer(layer, 1, rB, startT, endT, s.col);
            CreateSessionLabelGlobal(layer, 1, lB, startT, endT, s.name);
         }
         if(doT)
         {
            string rT = RectNameSpan(prefRect, SIDE_TOP, day0, i);
            string lT = LabelNameSpan(prefLbl,  SIDE_TOP, day0, i);
            CreateSessionRectLayer(layer, 0, rT, startT, endT, s.col);
            CreateSessionLabelGlobal(layer, 0, lT, startT, endT, s.name);
         }
      }
   }
}

// -------------------- Month cycle helpers --------------------
datetime MonthStart00(datetime t)
{
   int y = TimeYear(t);
   int m = TimeMonth(t);
   return MakeDateTimeSafe(y, m, 1, 0, 0, 0);
}

datetime AddMonths00(datetime t, int addMonths)
{
   int y = TimeYear(t);
   int m = TimeMonth(t);

   m += addMonths;
   while(m > 12) { m -= 12; y++; }
   while(m < 1)  { m += 12; y--; }

   return MakeDateTimeSafe(y, m, 1, 0, 0, 0);
}

datetime FirstDOWStartInMonth(datetime anyInMonth, int weekDOW, int hh, int mm, int offsetMin)
{
   datetime m0 = MonthStart00(anyInMonth);

   datetime d = DayStart(m0);
   int dow = TimeDayOfWeek(d);
   int delta = (weekDOW - dow + 7) % 7;
   d = d + delta * 86400;

   datetime cand = d + (hh*60 + mm + offsetMin) * 60;
   if(cand < m0) cand += 7*86400;

   return cand;
}

void L3_GetWNameAndColor(int weekIndex, string &nm, color &cl)
{
   int idx = weekIndex;
   if(idx < 0) idx = 0;
   if(idx > 3) idx = 3;

   if(idx == 0) { nm = L3_W1_Name; cl = L3_W1_Color; return; }
   if(idx == 1) { nm = L3_W2_Name; cl = L3_W2_Color; return; }
   if(idx == 2) { nm = L3_W3_Name; cl = L3_W3_Color; return; }
   nm = L3_W4_Name; cl = L3_W4_Color;
}

void BuildLayer3Monthly4Weeks()
{
   if(!TimeframeAllowed()) return;
   if(!L3_Enable) return;

   int wh, wm;
   if(!ParseHHMM(Month_cycle_start_HHMM, wh, wm)) return;
   if(Month_cycle_start_DOW < 0 || Month_cycle_start_DOW > 6) return;

   datetime today0 = DayStart(TimeCurrent());
   int offsetMin = (int)MathRound(TimeOffsetHours * 60.0);

   bool doB = WantBottom();
   bool doT = WantTop();

   for(int d = -DaysForward; d <= DaysBack; d++)
   {
      datetime day0 = today0 - d*86400;

      if(TimeDayOfWeek(day0) != Month_cycle_start_DOW) continue;

      datetime weekStart = day0 + (wh*60 + wm + offsetMin) * 60;

      datetime thisMonth0 = MonthStart00(weekStart);
      datetime pStart = FirstDOWStartInMonth(thisMonth0, Month_cycle_start_DOW, wh, wm, offsetMin);
      datetime pEnd   = pStart + 28*86400;

      if(weekStart < pStart)
      {
         datetime prevMonth0 = AddMonths00(thisMonth0, -1);
         pStart = FirstDOWStartInMonth(prevMonth0, Month_cycle_start_DOW, wh, wm, offsetMin);
         pEnd   = pStart + 28*86400;
      }

      if(weekStart < pStart || weekStart >= pEnd) continue;

      datetime weekEnd = weekStart + 7*86400;
      if(weekEnd > pEnd) weekEnd = pEnd;
      if(weekEnd <= weekStart) continue;

      int weekIndex = (int)((weekStart - pStart) / (7*86400));
      string nm; color cl;
      L3_GetWNameAndColor(weekIndex, nm, cl);

      if(doB)
      {
         string rB = RectNamePeriod(PREFIX_RECT_L3, SIDE_BOTTOM, weekStart);
         string lB = LabelNamePeriod(PREFIX_LBL_L3, SIDE_BOTTOM, weekStart);
         CreateSessionRectLayer(LAYER_L3, 1, rB, weekStart, weekEnd, cl);
         CreateSessionLabelGlobal(LAYER_L3, 1, lB, weekStart, weekEnd, nm);
      }
      if(doT)
      {
         string rT = RectNamePeriod(PREFIX_RECT_L3, SIDE_TOP, weekStart);
         string lT = LabelNamePeriod(PREFIX_LBL_L3, SIDE_TOP, weekStart);
         CreateSessionRectLayer(LAYER_L3, 0, rT, weekStart, weekEnd, cl);
         CreateSessionLabelGlobal(LAYER_L3, 0, lT, weekStart, weekEnd, nm);
      }
   }
}

// -------------------- Year cycle helpers --------------------
datetime FiscalYearStartForDate(datetime t)
{
   int y = TimeYear(t);
   datetime fyThis = MakeDateTimeSafe(y, Year_Cycle_Start_Month, Year_Cycle_Start_Day, 0, 0, 0);
   if(t < fyThis) fyThis = MakeDateTimeSafe(y - 1, Year_Cycle_Start_Month, Year_Cycle_Start_Day, 0, 0, 0);
   return fyThis;
}

void GetYearQuarterNameColor(int qIndex, string &nm, color &cl)
{
   if(qIndex <= 0) { nm = Year_Label_Prefix + "1"; cl = YEAR_cycle_Q1_color; return; }
   if(qIndex == 1) { nm = Year_Label_Prefix + "2"; cl = YEAR_cycle_Q2_color; return; }
   if(qIndex == 2) { nm = Year_Label_Prefix + "3"; cl = YEAR_cycle_Q3_color; return; }
   nm = Year_Label_Prefix + "4"; cl = YEAR_cycle_Q4_color;
}

void BuildLayer4YearCycle()
{
   if(!TimeframeAllowed()) return;
   if(!YEAR_cycle_enable) return;

   datetime today0   = DayStart(TimeCurrent());
   datetime rangeMin = today0 - DaysBack * 86400;
   datetime rangeMax = today0 + (DaysForward + 1) * 86400;

   bool doB = WantBottom();
   bool doT = WantTop();

   datetime fyStart = FiscalYearStartForDate(rangeMin);
   fyStart = AddYearsKeepDate(fyStart, -1);

   for(int y=0; y<8; y++)
   {
      datetime q1 = fyStart;
      datetime q2 = AddMonthsKeepDay(q1, 3);
      datetime q3 = AddMonthsKeepDay(q1, 6);
      datetime q4 = AddMonthsKeepDay(q1, 9);
      datetime q5 = AddYearsKeepDate(q1, 1);

      datetime starts[4];
      datetime ends[4];
      starts[0]=q1; ends[0]=q2;
      starts[1]=q2; ends[1]=q3;
      starts[2]=q3; ends[2]=q4;
      starts[3]=q4; ends[3]=q5;

      for(int i=0; i<4; i++)
      {
         if(ends[i] <= rangeMin || starts[i] >= rangeMax) continue;

         string nm; color cl;
         GetYearQuarterNameColor(i, nm, cl);

         if(doB)
         {
            string rB = RectNamePeriod(PREFIX_RECT_L4, SIDE_BOTTOM, starts[i]);
            string lB = LabelNamePeriod(PREFIX_LBL_L4, SIDE_BOTTOM, starts[i]);
            CreateSessionRectLayer(LAYER_L4, 1, rB, starts[i], ends[i], cl);
            CreateSessionLabelGlobal(LAYER_L4, 1, lB, starts[i], ends[i], nm);
         }
         if(doT)
         {
            string rT = RectNamePeriod(PREFIX_RECT_L4, SIDE_TOP, starts[i]);
            string lT = LabelNamePeriod(PREFIX_LBL_L4, SIDE_TOP, starts[i]);
            CreateSessionRectLayer(LAYER_L4, 0, rT, starts[i], ends[i], cl);
            CreateSessionLabelGlobal(LAYER_L4, 0, lT, starts[i], ends[i], nm);
         }
      }

      fyStart = AddYearsKeepDate(fyStart, 1);
      if(fyStart > rangeMax + 370*86400) break;
   }
}

// -------------------- 4 Year cycle helpers --------------------
void GetFourYearQuarterNameColor(int qIndex, string &nm, color &cl)
{
   if(qIndex <= 0) { nm = Four_Year_Cycle_Q1_name; cl = Four_Year_Cycle_Q1_Color; return; }
   if(qIndex == 1) { nm = Four_Year_Cycle_Q2_name; cl = Four_Year_Cycle_Q2_Color; return; }
   if(qIndex == 2) { nm = Four_Year_Cycle_Q3_name; cl = Four_Year_Cycle_Q3_Color; return; }
   nm = Four_Year_Cycle_Q4_name; cl = Four_Year_Cycle_Q4_Color;
}

void BuildLayer5FourYearCycle()
{
   if(!TimeframeAllowed()) return;
   if(!Four_Year_Cycle_Enable) return;

   int sy, sm, sd;
   if(!ParseYYYYMMDD(Four_Year_Cycle_Start, sy, sm, sd)) return;

   datetime cycle0   = MakeDateTimeSafe(sy, sm, sd, 0, 0, 0);
   datetime today0   = DayStart(TimeCurrent());
   datetime rangeMin = today0 - DaysBack * 86400;
   datetime rangeMax = today0 + (DaysForward + 1) * 86400;

   bool doB = WantBottom();
   bool doT = WantTop();

   datetime buildStart = AddYearsKeepDate(cycle0, -8);
   datetime buildEnd   = AddYearsKeepDate(cycle0, 12);

   datetime cur = buildStart;
   while(cur < buildEnd)
   {
      datetime p1 = cur;
      datetime p2 = AddYearsKeepDate(cur, 1);
      datetime p3 = AddYearsKeepDate(cur, 2);
      datetime p4 = AddYearsKeepDate(cur, 3);
      datetime p5 = AddYearsKeepDate(cur, 4);

      datetime starts[4];
      datetime ends[4];
      starts[0]=p1; ends[0]=p2;
      starts[1]=p2; ends[1]=p3;
      starts[2]=p3; ends[2]=p4;
      starts[3]=p4; ends[3]=p5;

      for(int i=0; i<4; i++)
      {
         if(ends[i] <= rangeMin || starts[i] >= rangeMax) continue;

         string nm; color cl;
         GetFourYearQuarterNameColor(i, nm, cl);

         if(doB)
         {
            string rB = RectNamePeriod(PREFIX_RECT_L5, SIDE_BOTTOM, starts[i]);
            string lB = LabelNamePeriod(PREFIX_LBL_L5, SIDE_BOTTOM, starts[i]);
            CreateSessionRectLayer(LAYER_L5, 1, rB, starts[i], ends[i], cl);
            CreateSessionLabelGlobal(LAYER_L5, 1, lB, starts[i], ends[i], nm);
         }
         if(doT)
         {
            string rT = RectNamePeriod(PREFIX_RECT_L5, SIDE_TOP, starts[i]);
            string lT = LabelNamePeriod(PREFIX_LBL_L5, SIDE_TOP, starts[i]);
            CreateSessionRectLayer(LAYER_L5, 0, rT, starts[i], ends[i], cl);
            CreateSessionLabelGlobal(LAYER_L5, 0, lT, starts[i], ends[i], nm);
         }
      }

      cur = AddYearsKeepDate(cur, 4);
   }
}

void BuildMicroLayerFrom90m()
{
   if(!TimeframeAllowed()) return;
   if(!Micro_Enable) return;
   if(!L0_Enable) return;

   datetime today0 = DayStart(TimeCurrent());
   int offsetMin = (int)MathRound(TimeOffsetHours * 60.0);

   for(int d = -DaysForward; d <= DaysBack; d++)
   {
      datetime day0 = today0 - d*86400;

      for(int i=0; i<16; i++)
      {
         SessionDef s = sessions0[i];
         if(!s.enable) continue;

         int sh, sm, eh, em;
         if(!ParseHHMM(s.start, sh, sm)) continue;
         if(!ParseHHMM(s.end,   eh, em)) continue;

         datetime startT = day0 + (sh*60 + sm + offsetMin) * 60;
         datetime endT   = day0 + (eh*60 + em + offsetMin) * 60;

         BuildMicroFor90Slot(day0, i, startT, endT);
      }
   }
}

// -------------------- Build All --------------------
void BuildAll()
{
   BuildMicroLayerFrom90m();
   BuildDailyLayer(LAYER_90M, PREFIX_RECT_L0, PREFIX_LBL_L0, L0_Enable, sessions0, 16);
   BuildLayer1();
   BuildSpanLayer(LAYER_L2, PREFIX_RECT_L2, PREFIX_LBL_L2, L2_Enable, sessions2, 4);
   BuildLayer3Monthly4Weeks();
   BuildLayer4YearCycle();
   BuildLayer5FourYearCycle();
}

// -------------------- MT4 Events --------------------
int init()
{
   IndicatorShortName(IND_NAME);

   SetIndexBuffer(0, bufMin);
   SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 1, clrNONE);

   SetIndexBuffer(1, bufMax);
   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 1, clrNONE);

   RefreshInputsToArrays();
   CleanupPlacementObjects();

   g_win = WindowFind(IND_NAME);
   BuildAll();

   g_lastBarTime      = 0;
   g_lastPeriod       = Period();
   g_lastPlacement    = BandPlacement;
   g_lastBars         = 0;
   g_firstStart       = true;
   g_tfObjectsDeleted = false;

   return(0);
}

int deinit()
{
   DeleteAllIndicatorObjects();
   return(0);
}

int start()
{
   int bars = Bars;

   // only refill static guide buffers when bar count changes
   if(bars != g_lastBars)
   {
      for(int i=0; i<bars; i++)
      {
         bufMin[i] = 0.0;
         bufMax[i] = 1.0;
      }
      g_lastBars = bars;
   }

   // if TF is not allowed, delete indicator objects once and stop
   if(!TimeframeAllowed())
   {
      if(!g_tfObjectsDeleted)
      {
         DeleteAllIndicatorObjects();
         g_tfObjectsDeleted = true;
      }
      return(0);
   }

   g_tfObjectsDeleted = false;

   bool newBar           = (Time[0] != g_lastBarTime);
   bool tfChanged        = (Period() != g_lastPeriod);
   bool placementChanged = (BandPlacement != g_lastPlacement);

   // heavy work only when needed
   if(g_firstStart || newBar || tfChanged || placementChanged)
   {
      g_lastBarTime   = Time[0];
      g_lastPeriod    = Period();
      g_lastPlacement = BandPlacement;

      RefreshInputsToArrays();

      if(g_firstStart || placementChanged)
         CleanupPlacementObjects();

      g_win = -1;
      EnsureWindowIndex();
      BuildAll();

      g_firstStart = false;
   }

   // IMPORTANT:
   // We intentionally do NOT rescan all chart objects here.
   // That was one of the two biggest load producers.

   return(0);
}