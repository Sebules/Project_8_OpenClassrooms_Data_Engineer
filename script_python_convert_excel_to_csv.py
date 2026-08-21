import pandas as pd
from dotenv import load_dotenv
import os
import json

load_dotenv(".env.convert_xlsx_csv") # load variables from .env.convert_xlsx_csv file

INPUT_FILES = json.loads(os.getenv("INPUT_FILES", "[]")) # get input files from environment variable
OUTPUT_FILES = json.loads(os.getenv("OUTPUT_FILES", "[]")) # get output files from environment variable

for input_file, output_file in zip(INPUT_FILES, OUTPUT_FILES):
    # Read the Excel file
    sheets = pd.read_excel(input_file,sheet_name=None)  # Read all sheets into a dictionary of DataFrames

    frames = []
    for tab_name, df in sheets.items():
        df['tab_name'] = tab_name  # Add a new column with the sheet name
        frames.append(df)
    result = pd.concat(frames, ignore_index=True)  # Concatenate all DataFrames into one
    result["Date"] = pd.to_datetime(result["tab_name"], format="%d%m%y")  # Convert the 'tab_name' column to datetime

    columns = ['Time', 'Temperature', 'Humidity', 'Wind', 'Speed', 'Gust',
               'Pressure', 'Precip. Rate.', 'Precip. Accum.','UV', 'Solar']
    result = result.dropna(subset=columns, how='all', axis=0,ignore_index=True)  # Drop rows where all specified columns are NaN

    result.to_csv('donnees/' + output_file, encoding='utf-8', index=False)  # Save the DataFrame to a CSV file
    print(f"File {output_file} created successfully. {result.shape[0]} rows saved.")
    # Save the DataFrame


