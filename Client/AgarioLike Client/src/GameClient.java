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
                        int action = in.readByte();
                        int keyVal = in.readByte();

                        if (action == 1) {
                            System.out.println("Server confirmou: Pressionaste a tecla " + (char)keyVal);
                        } else {
                            System.out.println("Server confirmou: Soltaste a tecla " + (char)keyVal);
                        }
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

    public void Key(int a, char key){
        try{
            out.writeShort(3);

            out.writeByte(2);
            out.writeByte(a);
            out.writeByte(key);

            out.flush();
        }
        catch (IOException e){
            e.printStackTrace();
        }
    }
}