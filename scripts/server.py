import socket
import sys
import subprocess

HOST = "192.168.2.9" #host IPv4

class Server:
    
    def __init__(self, port):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.bind((HOST, port))
        self.port = port
        print("[-] Server listening on port " + str(port))
        print("[-] Server is ready to receive\n")

    def start(self):
        while True:
            self.socket.listen(1) #max 1 request and refuse connections
            conn, addr = self.socket.accept()
            
            if conn:
                conn.send(b"[-] Establishing connection...\n")
                conn.send(b"[-] Connection established successfully with host "
                + b"(" + HOST.encode() + b", " + str(self.port).encode() + b")\n\n")

            while True:
                data = conn.recv(1024)
                print("Incoming: " + str(addr))
                print("Message: " + data.decode() + "\n")
                conn.send(b"Successfully Delivered: " + data + b"\n")
                #Cleaner response can be done here

                data_str = data.decode()
                with open("../logs/%s.txt" % HOST, "w") as f:
                    f.write(data_str)
                f.close()
                
                cmd = "echo \'" + data_str + "\' | ./script.sh"
                subprocess.call(cmd, shell=True)
        
            conn.close()

Server(int(sys.argv[1])).start()
