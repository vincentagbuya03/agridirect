
import os

file_path = r'c:\Users\Nick Vincent Agbuya\Documents\Flutter Project\agridirect\.env'
with open(file_path, 'rb') as f:
    content = f.read()
    print(f"Content: {content}")
