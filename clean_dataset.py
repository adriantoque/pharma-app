import pandas as pd

input_file = r'D:\DEVELOPMENT_FILES_FOLDER\PharmaGuide\Daily Sales Tracker.xlsx'
output_file = r'D:\DEVELOPMENT_FILES_FOLDER\PharmaGuide\Cleaned_Sales_Tracker.csv'

try:
    # Load the Excel file without headers to find where the table actually starts
    df_raw = pd.read_excel(input_file, header=None)

    # Find the row index where 'Item Name' is located
    header_row_index = None
    for i, row in df_raw.iterrows():
        if 'Item Name' in row.values:
            header_row_index = i
            break

    if header_row_index is not None:
        print(f"Found table header at row {header_row_index}")

        # Re-read the file starting from the header row
        df = pd.read_excel(input_file, skiprows=header_row_index)

        # Clean column names (strip whitespace)
        df.columns = [str(col).strip() for col in df.columns]
        print("Cleaned columns:", df.columns.tolist())

        # We need 'Item Name' and 'Unit Price'
        name_col = 'Item Name'
        price_col = 'Unit Price'

        if name_col in df.columns and price_col in df.columns:
            # Ensure price is numeric
            df[price_col] = pd.to_numeric(df[price_col], errors='coerce')

            # Remove rows where name or price is NaN
            df = df.dropna(subset=[name_col, price_col])

            # Sort by name and then by price (ascending) to keep the lowest price
            df_sorted = df.sort_values(by=[name_col, price_col], ascending=[True, True])

            # Drop duplicates based on name, keeping the first occurrence (lowest price)
            df_cleaned = df_sorted.drop_duplicates(subset=[name_col], keep='first')

            # Save to CSV
            df_cleaned.to_csv(output_file, index=False)
            print(f"Cleaned data saved to {output_file}")
            print(f"Removed {len(df) - len(df_cleaned)} duplicates.")
        else:
            print(f"Could not find required columns. Available: {df.columns.tolist()}")
    else:
        print("Could not find 'Item Name' in the file.")

except Exception as e:
    print(f"An error occurred: {e}")
