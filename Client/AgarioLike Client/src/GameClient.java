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

            new Thread(this::listenFromServer).start();

            System.out.println("Connected to Erlang server!");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public void sendPacket(int id, byte[] payload) {
        try {
            int totalLength = 1 + payload.length;
            out.writeShort(totalLength);

            out.writeByte(id);

            out.write(payload);
            out.flush();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void listenFromServer() {
        try {
            while (true) {
                int length = in.readUnsignedShort();

                int packetId = in.readByte();

                switch (packetId) {
                    case 101:
                        int x = in.readShort();
                        int y = in.readShort();
                        System.out.println("Spawned at: " + x + ", " + y);
                        break;

                    case 2:

                        int c = in.readByte();
                        System.out.println("Pressed key: " + c);
                        break;

                    default:
                        System.out.println("Unknown packet ID: " + packetId);
                        in.skipBytes(length - 1);
                        break;
                }
            }
        } catch (IOException e) {
            System.out.println("Disconnected from server.");
        }
    }
}