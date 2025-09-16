import SwiftUI

struct ContentView: View {
    
    @StateObject private var tcpManager = TCPManager()
    @StateObject private var bluetoothManager = BluetoothManager()
    
    @State private var host: String = "127.0.0.1"
    @State private var port: String = "1234"

    var body: some View {
        VStack(spacing: 12) {
            // MARK: TCP Controls
            VStack {
                HStack {
                    TextField("Server Host IP", text: $host)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Server Port", text: $port)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
                Text(tcpManager.connectionState).font(.caption).foregroundColor(.secondary)
                HStack {
                    Button("Connect TCP") {
                        updateBluetoothManagerServerDetails()
                        tcpManager.connect(host: host, port: Int(port) ?? 0)
                    }.buttonStyle(.borderedProminent).tint(.green)
                    Button("Disconnect TCP") {
                        tcpManager.disconnect()
                    }.buttonStyle(.borderedProminent).tint(.red)
                }
            }.padding([.horizontal, .top])
            
            Divider()

            // MARK: Bluetooth Controls
            VStack {
                Text(bluetoothManager.bluetoothState).font(.caption2).foregroundColor(.secondary)
                Text(bluetoothManager.peripheralStatus).font(.caption).foregroundColor(.secondary)
                Button("Scan and Connect to Device") {
                    updateBluetoothManagerServerDetails()
                    bluetoothManager.startScanning()
                }.buttonStyle(.bordered).tint(.blue)
            }
            
            Divider()

            // MARK: Communication Log
            Text("In-App Communication Log").font(.headline)
            List(tcpManager.messages, id: \.self) { message in
                Text(message).padding(2)
            }.listStyle(PlainListStyle()).border(Color.gray.opacity(0.2))
        }
        .padding(.top)
        .onAppear(perform: { bluetoothManager.tcpManager = tcpManager })
        .onChange(of: tcpManager.messages) { newMessages in
            guard let lastMessage = newMessages.last else { return }
            
            if lastMessage.hasPrefix("[Server]:") {
                let contentToSend = lastMessage.dropFirst("[Server]: ".count).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !contentToSend.isEmpty {
                    print("Forwarding server message to Bluetooth device: \(contentToSend)")
                    bluetoothManager.writeString(String(contentToSend))
                }
            }
        }
    }
    
    private func updateBluetoothManagerServerDetails() {
        bluetoothManager.lastKnownHost = host
        bluetoothManager.lastKnownPort = Int(port)
    }
}
