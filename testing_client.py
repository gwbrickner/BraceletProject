import socket
import threading


def receive_messages(client_socket):
    while True:
        try:
            message = client_socket.recv(1024).decode('utf-8')
            if message:
                print(message)
            else:
                print("[DISCONNECTED] Server connection lost.")
                break
        except:
            print("[DISCONNECTED] Server connection lost unexpectedly.")
            break


def run_client():
    # Replace 'SERVER_IP' with the actual IP address of the computer running the server
    SERVER_IP = '0.0.0.0'  # Example: use the IP printed by the server script
    PORT = 44451
    ADDR = (SERVER_IP, PORT)

    try:
        client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client.connect(ADDR)

        print(f"[CONNECTED] Connected to server at {SERVER_IP}:{PORT}")

        # Start a thread to continuously receive messages from the server
        threading.Thread(target=receive_messages, args=(client,)).start()

        # Main thread for sending messages
        while True:
            message = input()
            if message.lower() == 'quit':
                break
            client.send(message.encode('utf-8'))

    except ConnectionRefusedError:
        print("[ERROR] Connection refused. Make sure the server is running.")
    except Exception as e:
        print(f"[ERROR] An error occurred: {e}")
    finally:
        client.close()


if __name__ == "__main__":
    run_client()
