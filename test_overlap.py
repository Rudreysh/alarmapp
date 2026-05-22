berlin_start_local = 9.0
berlin_end_local = 17.0
blore_start_local = 9.0
blore_end_local = 17.0

berlin_offset = 1.0 # GMT+1
blore_offset = 5.5 # GMT+5.5

berlin_start_gmt = berlin_start_local - berlin_offset
berlin_end_gmt = berlin_end_local - berlin_offset

blore_start_gmt = blore_start_local - blore_offset
blore_end_gmt = blore_end_local - blore_offset

overlap_start_gmt = max(berlin_start_gmt, blore_start_gmt)
overlap_end_gmt = min(berlin_end_gmt, blore_end_gmt)
duration = overlap_end_gmt - overlap_start_gmt

print(f"Berlin GMT: {berlin_start_gmt} to {berlin_end_gmt}")
print(f"Bengaluru GMT: {blore_start_gmt} to {blore_end_gmt}")
print(f"Overlap duration: {duration} hours")
