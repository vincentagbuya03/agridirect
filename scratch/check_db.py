import urllib.request
import json

url_orders = "https://ywfppgarzyksacgbesme.supabase.co/rest/v1/orders?select=*,order_statuses(*),order_items(*)"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs"
}

req = urllib.request.Request(url_orders, headers=headers)
try:
    with urllib.request.urlopen(req) as response:
        data = response.read().decode('utf-8')
        orders = json.loads(data)
        print("=== ORDERS ===")
        for o in orders:
            print(f"Order Number: {o.get('order_number')}, Status: {o.get('order_statuses', {}).get('code')}, Subtotal: {o.get('subtotal')}")
            for item in o.get('order_items', []):
                print(f"  - Item: {item.get('product_id')}, Qty: {item.get('quantity')}")
except Exception as e:
    print("Error:", e)
