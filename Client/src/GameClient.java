import java.io.*;
import java.net.Socket;

public class GameClient {
    private Socket socket;
    private DataOutputStream out;
    private DataInputStream in;

    public void connect(String host, int port) {
        try {
            socket = new Socket(host, port);
            out = new DataOutputStream(socket.getOutputStream());
            in = new DataInputStream(socket.getInputStream());

            // Start a separate thread to listen for server updates
            new Thread(this::listenFromServer).start();

            System.out.println("Connected to Erlang server!");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    // This method corresponds to Erlang's {packet, 2}
    public void sendPacket(int id, byte[] payload) {
        try {
            // Write the total length of the message (ID + Payload)
            // {packet, 2} expects a 16-bit unsigned integer prefix
            int totalLength = 1 + payload.length;
            out.writeShort(totalLength);

            // Write the Packet ID
            out.writeByte(id);

            // Write the data
            out.write(payload);
            out.flush();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void listenFromServer() {
        try {
            while (true) {
                // 1. Read the 2-byte length header (handled by DataInputStream)
                int length = in.readUnsignedShort();

                // 2. Read the Packet ID
                int packetId = in.readByte();

                // 3. Handle based on ID
                switch (packetId) {
                    case 101: // Login Success
                        int x = in.readShort();
                        int y = in.readShort();
                        System.out.println("Spawned at: " + x + ", " + y);
                        // Here you would trigger a method to update your Java GUI
                        break;

                    default:
                        System.out.println("Unknown packet ID: " + packetId);
                        // Skip the rest of the payload if unknown
                        in.skipBytes(length - 1);
                        break;
                }
            }
        } catch (IOException e) {
            System.out.println("Disconnected from server.");
        }
    }
}