#!/usr/bin/env python3
"""
Test script for theorems_sessions_bottom_pane.pine - quarterly cycle math.
Validates Python port of f_cycle_math for the 90min cycle.
"""

from datetime import datetime, timezone
import json

CYCLE_90M_MS = 90 * 60 * 1000
QUARTER_90M_MS = CYCLE_90M_MS // 4  # 1,350,000 ms = 22.5 min
CYCLE_6H_MS = 6 * 60 * 60 * 1000
QUARTER_6H_MS = CYCLE_6H_MS // 4    # 5,400,000 ms = 90 min


def cycle_math(t_ms, anchor_ms, cycle_ms):
    """Pure port of Pine's f_cycle_math. Python // already floors for negatives."""
    cycle_idx = (t_ms - anchor_ms) // cycle_ms
    cycle_start = anchor_ms + cycle_idx * cycle_ms
    quarter_ms = cycle_ms // 4
    quarter_idx = (t_ms - cycle_start) // quarter_ms
    return cycle_start, quarter_idx


def dt_to_ms(dt):
    return int(dt.replace(tzinfo=timezone.utc).timestamp() * 1000)


class QuarterlyCyclesValidator:
    """Validator for quarterly cycle timing calculations."""

    def __init__(self):
        # Default master timing: Tuesday 21:15 UTC. Pick the nearest Tuesday.
        # 2026-04-14 is a Tuesday.
        self.anchor_dt = datetime(2026, 4, 14, 21, 15, 0)
        self.anchor_ms = dt_to_ms(self.anchor_dt)

    def test_90m_quarter_alignment(self):
        """Offsets relative to anchor should land in expected quarters."""
        print("\nTesting 90min cycle quarter alignment to anchor:")
        print("=" * 80)
        cases = [
            # (offset_min, expected_q, description)
            (0,    0, "Anchor → Q1 start"),
            (1,    0, "Anchor + 1m → Q1"),
            (22,   0, "Anchor + 22m → Q1 (just before boundary)"),
            (23,   1, "Anchor + 23m → Q2"),
            (45,   2, "Anchor + 45m → Q3"),
            (67,   2, "Anchor + 67m → Q3 (just before boundary)"),
            (68,   3, "Anchor + 68m → Q4"),
            (89,   3, "Anchor + 89m → Q4 (end of cycle)"),
            (90,   0, "Anchor + 90m → Q1 of next cycle"),
            (180,  0, "Anchor + 180m → Q1 two cycles later"),
            (-22,  3, "Anchor − 22m → Q4 of previous cycle"),
            (-90,  0, "Anchor − 90m → Q1 of previous cycle"),
        ]
        print(f"{'Offset (min)':<14} {'Q (actual)':<12} {'Q (expected)':<14} {'Status':<8} {'Description'}")
        print("-" * 80)
        all_passed = True
        for offset_min, expected_q, desc in cases:
            t_ms = self.anchor_ms + offset_min * 60 * 1000
            _, q_idx = cycle_math(t_ms, self.anchor_ms, CYCLE_90M_MS)
            ok = q_idx == expected_q
            status = "✓" if ok else "✗"
            print(f"{offset_min:<14} {q_idx:<12} {expected_q:<14} {status:<8} {desc}")
            if not ok:
                all_passed = False
        return all_passed

    def test_cycle_start_continuity(self):
        """Consecutive cycle starts must be exactly CYCLE_90M_MS apart."""
        print("\nTesting cycle start continuity:")
        print("=" * 80)
        starts = []
        for cycle_idx in range(-2, 5):
            # Pick a moment 10 seconds into cycle_idx (non-boundary)
            t_ms = self.anchor_ms + cycle_idx * CYCLE_90M_MS + 10_000
            cycle_start, _ = cycle_math(t_ms, self.anchor_ms, CYCLE_90M_MS)
            starts.append(cycle_start)

        all_passed = True
        for i in range(1, len(starts)):
            diff = starts[i] - starts[i - 1]
            ok = diff == CYCLE_90M_MS
            status = "✓" if ok else "✗"
            print(f"  cycle_start[{i}] - cycle_start[{i-1}] = {diff}ms ({diff/60000:.1f} min) {status}")
            if not ok:
                all_passed = False
        return all_passed

    def test_6h_quarter_alignment(self):
        """6-hour cycle: 4 quarters × 90 min. Each 6H Q-boundary must land on a 90M cycle start."""
        print("\nTesting 6-hour cycle quarter alignment to anchor:")
        print("=" * 80)
        cases = [
            # (offset_min, expected_q, description)
            (0,    0, "Anchor → Q1 start"),
            (89,   0, "Anchor + 89m → Q1 (last minute)"),
            (90,   1, "Anchor + 90m → Q2 start (also 90M cycle #2 start)"),
            (180,  2, "Anchor + 180m → Q3 start (also 90M cycle #3 start)"),
            (270,  3, "Anchor + 270m → Q4 start"),
            (359,  3, "Anchor + 359m → Q4 (last minute)"),
            (360,  0, "Anchor + 360m → Q1 of next 6H cycle"),
            (-1,   3, "Anchor − 1m → Q4 of previous 6H cycle"),
            (-90,  3, "Anchor − 90m → Q4 start of previous 6H cycle"),
            (-360, 0, "Anchor − 360m → Q1 of previous 6H cycle"),
        ]
        print(f"{'Offset (min)':<14} {'Q (actual)':<12} {'Q (expected)':<14} {'Status':<8} {'Description'}")
        print("-" * 80)
        all_passed = True
        for offset_min, expected_q, desc in cases:
            t_ms = self.anchor_ms + offset_min * 60 * 1000
            _, q_idx = cycle_math(t_ms, self.anchor_ms, CYCLE_6H_MS)
            ok = q_idx == expected_q
            status = "✓" if ok else "✗"
            print(f"{offset_min:<14} {q_idx:<12} {expected_q:<14} {status:<8} {desc}")
            if not ok:
                all_passed = False
        return all_passed

    def test_6h_aligns_with_90m(self):
        """Every 6H quarter boundary must coincide with a 90M cycle start."""
        print("\nTesting 6H quarter boundaries coincide with 90M cycle starts:")
        print("=" * 80)
        all_passed = True
        for q in range(4):
            boundary_ms = self.anchor_ms + q * QUARTER_6H_MS
            cycle_start_90m, q_idx_90m = cycle_math(boundary_ms, self.anchor_ms, CYCLE_90M_MS)
            ok = cycle_start_90m == boundary_ms and q_idx_90m == 0
            status = "✓" if ok else "✗"
            print(f"  6H Q{q+1} boundary @ anchor+{q*90}m → is 90M cycle start? {ok} {status}")
            if not ok:
                all_passed = False
        return all_passed

    def test_q1_starts_on_anchor(self):
        """Q1 of the cycle containing the anchor must start exactly at the anchor."""
        print("\nTesting Q1 lands on anchor timestamp:")
        print("=" * 80)
        cycle_start, q_idx = cycle_math(self.anchor_ms, self.anchor_ms, CYCLE_90M_MS)
        ok = cycle_start == self.anchor_ms and q_idx == 0
        status = "✓" if ok else "✗"
        print(f"  cycle_start == anchor: {cycle_start == self.anchor_ms}, q_idx == 0: {q_idx == 0} {status}")
        return ok

    def export_validation_data(self, filename="quarterly_cycles_validation.json"):
        """Export per-minute validation for one full cycle ± buffer."""
        print("\nExporting validation data...")
        entries = []
        for minute in range(-5, 95):
            t_ms = self.anchor_ms + minute * 60 * 1000
            cycle_start, q_idx = cycle_math(t_ms, self.anchor_ms, CYCLE_90M_MS)
            entries.append({
                "offset_min": minute,
                "t_ms": t_ms,
                "cycle_start_ms": cycle_start,
                "cycle_start_offset_min": (cycle_start - self.anchor_ms) // (60 * 1000),
                "quarter": int(q_idx),
            })

        payload = {
            "validation_timestamp": datetime.now().isoformat(),
            "indicator": "theorems_sessions_bottom_pane.pine",
            "cycle_ms": CYCLE_90M_MS,
            "quarter_ms": QUARTER_90M_MS,
            "anchor_iso": self.anchor_dt.isoformat(),
            "anchor_ms": self.anchor_ms,
            "entries": entries,
        }

        filepath = f"/Users/finnformica/Documents/programming/theorem-capital/trading-view-indicators/tests/{filename}"
        with open(filepath, 'w') as f:
            json.dump(payload, f, indent=2)
        print(f"✓ Validation data exported to: {filename}")
        return filepath


def main():
    v = QuarterlyCyclesValidator()
    print("Quarterly Cycles Indicator Test Suite (90min)")
    print("=" * 80)

    results = [
        v.test_90m_quarter_alignment(),
        v.test_cycle_start_continuity(),
        v.test_q1_starts_on_anchor(),
        v.test_6h_quarter_alignment(),
        v.test_6h_aligns_with_90m(),
    ]
    v.export_validation_data()

    print("\n" + "=" * 80)
    print("TEST SUMMARY")
    print("=" * 80)
    if all(results):
        print("✅ ALL TESTS PASSED")
        print("✅ 90min cycle math verified against expected boundaries")
        return True
    else:
        print("❌ SOME TESTS FAILED")
        return False


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
