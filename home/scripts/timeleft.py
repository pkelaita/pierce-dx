from datetime import date

# Variables
DAD_LIFE_EXPECTANCY_YEARS = 90
MOM_LIFE_EXPECTANCY_YEARS = 90
DAD_MONTHLY_FREQ_FORWARD = 2.0
MOM_MONTHLY_FREQ_FORWARD = 2.0

TODAY = date.today()

# Constants
BIRTH_DATE = date(1999, 7, 22)
COLLEGE_START = date(2017, 8, 15)
COLLEGE_END = date(2021, 9, 15)
DAD_BIRTHDATE = date(1963, 8, 18)
MOM_BIRTHDATE = date(1969, 8, 26)
DAYS_PER_MONTH = 365.2425 / 12.0


def span_days(start: date, end: date) -> int:
    """End-exclusive day count: [start, end)."""
    return max(0, (end - start).days)


def months_equiv(day_count: int) -> float:
    """Convert days to 'average months'."""
    return day_count / DAYS_PER_MONTH


def lifetime_end(born: date, life_expectancy_years: int) -> date:
    """Compute the date on which a person turns life_expectancy_years.
    (Safe for non–Feb 29 birthdays like these.)"""
    return date(born.year + life_expectancy_years, born.month, born.day)


# Assumptions: Monthly frequencies by phase (days/month, averaged):
# - Until college: 20 days/month each
# - During college: 0.5 days/month each
# - After college: Dad 1.5 days/month, Mom 1.0 days/month


# Phase 1: Before college
phase1_start = BIRTH_DATE
phase1_end = COLLEGE_START
phase1_days = span_days(phase1_start, phase1_end)
phase1_months = months_equiv(phase1_days)
phase1_dad_days = 20.0 * phase1_months
phase1_mom_days = 20.0 * phase1_months

# Phase 2: During college
phase2_start = COLLEGE_START
phase2_end = COLLEGE_END
phase2_days = span_days(phase2_start, phase2_end)
phase2_months = months_equiv(phase2_days)
phase2_dad_days = 2 * phase2_months
phase2_mom_days = 2 * phase2_months

# Phase 3: After college to TODAY
phase3_start = COLLEGE_END
phase3_end = TODAY
phase3_days = span_days(phase3_start, phase3_end)
phase3_months = months_equiv(phase3_days)
phase3_dad_days = 1.75 * phase3_months
phase3_mom_days = 1.5 * phase3_months

dad_spent_so_far = phase1_dad_days + phase2_dad_days + phase3_dad_days
mom_spent_so_far = phase1_mom_days + phase2_mom_days + phase3_mom_days

# Forward: from TODAY until each death
dad_end_of_life = lifetime_end(DAD_BIRTHDATE, DAD_LIFE_EXPECTANCY_YEARS)
mom_end_of_life = lifetime_end(MOM_BIRTHDATE, MOM_LIFE_EXPECTANCY_YEARS)

dad_days_remaining = max(0, (dad_end_of_life - TODAY).days)
mom_days_remaining = max(0, (mom_end_of_life - TODAY).days)

dad_months_remaining = months_equiv(dad_days_remaining)
mom_months_remaining = months_equiv(mom_days_remaining)

dad_days_left = DAD_MONTHLY_FREQ_FORWARD * dad_months_remaining
mom_days_left = MOM_MONTHLY_FREQ_FORWARD * mom_months_remaining

# Percent used
dad_total_expected = dad_spent_so_far + dad_days_left
mom_total_expected = mom_spent_so_far + mom_days_left

dad_percent_used = (
    (dad_spent_so_far / dad_total_expected * 100.0) if dad_total_expected > 0 else 0.0
)
mom_percent_used = (
    (mom_spent_so_far / mom_total_expected * 100.0) if mom_total_expected > 0 else 0.0
)


# Output
def r(x):
    return int(round(x))


print("Inputs")
print(f"TODAY: {TODAY.isoformat()}")
print(f"DAD_LIFE_EXPECTANCY_YEARS = {DAD_LIFE_EXPECTANCY_YEARS}")
print(f"MOM_LIFE_EXPECTANCY_YEARS = {MOM_LIFE_EXPECTANCY_YEARS}")
print(f"DAD_MONTHLY_FREQ_FORWARD  = {DAD_MONTHLY_FREQ_FORWARD} days/month")
print(f"MOM_MONTHLY_FREQ_FORWARD  = {MOM_MONTHLY_FREQ_FORWARD} days/month")
print()
print("Days spent with each parent (by phase):")
print(f"Phase 1 (birth → college): Dad {r(phase1_dad_days)}, Mom {r(phase1_mom_days)}")
print(f"Phase 2 (during college): Dad {r(phase2_dad_days)}, Mom {r(phase2_mom_days)}")
print(f"Phase 3 (college → TODAY): Dad {r(phase3_dad_days)}, Mom {r(phase3_mom_days)}")
print()
print("Days left with each:")
print(f"Dad days left: {r(dad_days_left)} (until {dad_end_of_life.isoformat()})")
print(f"Mom days left: {r(mom_days_left)} (until {mom_end_of_life.isoformat()})")
print()
print("Percentage of days used:")
print(f"Dad: {dad_percent_used:.1f}%")
print(f"Mom: {mom_percent_used:.1f}%")
