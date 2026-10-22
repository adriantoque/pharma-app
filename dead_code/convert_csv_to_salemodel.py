import csv
import json
from datetime import date

# Normalise function (same as in import_sales_tracker.dart)
def normalise(value):
    return value.lower().replace(r'[^a-z0-9]', '')

# Read the cleaned CSV
rows = []
with open('Cleaned_Sales_Tracker.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        rows.append(row)

# Convert each row to SaleModel format
saleModels = []
for i, row in enumerate(rows):
    rawName = row['Item Name'].strip()
    if not rawName:
        continue
    
    quantity = float(row['Quantity'].strip()) if row['Quantity'] else 0
    unitPrice = float(row['Unit Price'].strip()) if row['Unit Price'] else 0
    totalPrice = float(row['Total Price'].strip()) if row['Total Price'] else 0
    
    # Normalise the name
    key = normalise(rawName)
    
    # Assign a date - using 2025 and distributing across months
    # The original data runs July-September 2025
    month = 7 + (i % 3)  # July, August, September
    day = (i % 28) + 1     # 1-28
    saleDate = date(2025, month, day)
    
    saleModel = {
        'date': saleDate.isoformat()[:10],
        'kind': 'counter',
        'rawName': rawName,
        'key': key,
        'quantity': quantity,
        'priceCentavos': int(round(unitPrice * 100)),
        'totalCentavos': int(round(totalPrice * 100)),
        'sourceSheet': 'cleaned_csv',
    }
    saleModels.append(saleModel)

# Output as JSON
outputJson = json.dumps(saleModels, indent=2)
with open('assets/data/cleaned_sales_seed.json', 'w', encoding='utf-8') as f:
    f.write(outputJson + '\n')

print(f'Converted {len(saleModels)} sale records from CSV')
print(f'Written to assets/data/cleaned_sales_seed.json')