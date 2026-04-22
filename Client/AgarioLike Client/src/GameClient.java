import java.io.*;
import java.net.Socket;
import java.nio.charset.StandardCharsets;

public class GameClient {
    private Socket socket;
    private DataOutputStream out;
    private DataInputStream in;
    private GameApp app; // Reference to Processing app to update coordinates

    public GameClient(GameApp app) {
        this.app = app;
    }

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

    // Protocol: [0] + [Username Bytes]
    public void sendLogin(String username) {
        try {
            byte[] nameBytes = username.getBytes(StandardCharsets.UTF_8);
            byte[] packet = new byte[1 + nameBytes.length];
            packet[0] = 0;
            System.arraycopy(nameBytes, 0, packet, 1, nameBytes.length);

            out.write(packet);
            out.flush();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    // Protocol: [1] [Left] [Right] [Forward]
    public void sendMovement(int left, int right, int forward) {
        try {
            out.writeByte(1);
            out.writeByte(left);
            out.writeByte(right);
            out.writeByte(forward);
            out.flush();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void listenFromServer() {
        try {
            while (true) {
                byte packetId = in.readByte();

                if (packetId == 2) {
                    // Protocol: [2] [X:Float] [Y:Float] [Angle:Float] [Mass:Float]
                    float x = in.readFloat();
                    float y = in.readFloat();
                    float angle = in.readFloat();
                    float mass = in.readFloat();

                    // Tell the Processing app to update the screen!
                    app.updatePlayerState(x, y, angle, mass);
                } else {
                    System.out.println("Unknown packet ID: " + packetId);
                }
            }
        } catch (IOException e) {
            System.out.println("Disconnected from server.");
        }
    }
}