import csv
import json
import os

def convert_csv_to_jsonl(csv_path, jsonl_path):
    if not os.path.exists(csv_path):
        print(f"Error: {csv_path} not found.")
        return

    with open(csv_path, mode='r', encoding='utf-8') as csv_file:
        # Assumes columns: System Prompt, User Input, Assistant Output
        reader = csv.DictReader(csv_file)
        
        with open(jsonl_path, mode='w', encoding='utf-8') as jsonl_file:
            for row in reader:
                # Map CSV columns to the message structure
                # Adjust column names if your CSV uses different headers
                system_content = row.get('System Prompt', row.get('system', ''))
                user_content = row.get('User Input', row.get('input', ''))
                assistant_content = row.get('Assistant Output', row.get('output', ''))

                if not user_content or not assistant_content:
                    continue

                message_structure = {
                    "messages": [
                        {"role": "system", "content": system_content},
                        {"role": "user", "content": user_content},
                        {"role": "assistant", "content": assistant_content}
                    ]
                }
                jsonl_file.write(json.dumps(message_structure) + '\n')
    
    print(f"Successfully converted {csv_path} to {jsonl_path}")

if __name__ == "__main__":
    # You can change these filenames to match yours
    convert_csv_to_jsonl('lessons_data.csv', 'dataset.jsonl')
