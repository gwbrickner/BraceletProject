import socket
import threading

# code for handling client connections and messages sent
def handle_client(client_socket, addr, clients):
    print(f"[NEW CONNECTION] {addr} connected.")
    client_socket.send("You are connected to the server!".encode('utf-8'))

    # infinite loop for recieving messages
    while True:
        try:
            # only continues to further code if message is recieved
            message = client_socket.recv(1024).decode('utf-8')
            if message:
                print(f"[{addr}] {message}")
                # broadcast to every client, useful for bracelet as
                # when we recieve a ping from one we want that ping to
                # go to other one
                for client in clients:
                    if client != client_socket:
                        client.send(f"[{addr}] {message}".encode('utf-8'))
            else:
                # Remove client if connection is closed
                clients.remove(client_socket)
                print(f"[DISCONNECTED] {addr} disconnected.")
                break
        except:
            clients.remove(client_socket)
            print(f"[DISCONNECTED] {addr} disconnected unexpectedly.")
            break
    client_socket.close()


def run_server():
    HOST = '0.0.0.0'  # Gets the local IP address
    PORT = 44451
    ADDR = (HOST, PORT)
    clients = []

    # socket setup
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(ADDR)
    server.listen()

    print(f"[LISTENING] Server is listening on {HOST}:{PORT}")

    while True:
        # for each connection, make a new thread for handling said connection
        client_socket, addr = server.accept()
        clients.append(client_socket)
        thread = threading.Thread(target=handle_client, args=(client_socket, addr, clients))
        thread.start()
        print(f"[ACTIVE CONNECTIONS] {threading.active_count() - 1}")


if __name__ == "__main__":
    run_server()