import java.io.*;
import java.net.Socket;
import java.nio.charset.StandardCharsets;

public class GameClient {
    private Socket socket;
    private DataOutputStream out;
    private DataInputStream in;
    private GameApp app;

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

    // Handles Register (1), Login (2), and Cancel (3)
    public void sendAuthAction(int actionId, String username, String password) {
        try {
            byte[] userBytes = username.getBytes(StandardCharsets.UTF_8);
            byte[] passBytes = password.getBytes(StandardCharsets.UTF_8);

            // Build the packet entirely in memory before sending to prevent TCP fragmentation
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            DataOutputStream dos = new DataOutputStream(baos);

            dos.writeByte(actionId);
            dos.writeShort(userBytes.length);
            dos.write(userBytes);
            dos.writeShort(passBytes.length);
            dos.write(passBytes);

            out.write(baos.toByteArray());
            out.flush();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    // Protocol: [4] [Left] [Right] [Forward]
    public void sendMovement(int left, int right, int forward) {
        try {
            out.writeByte(4); // Changed to 4
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

                if (packetId == 16) {
                    // 0x10 Auth Response
                    byte status = in.readByte();
                    short msgLen = in.readShort();
                    byte[] msgBytes = new byte[msgLen];
                    in.readFully(msgBytes); // Ensure we read the exact length of the string

                    String message = new String(msgBytes, StandardCharsets.UTF_8);
                    System.out.println("[SERVER] " + (status == 1 ? "SUCCESS: " : "ERROR: ") + message);
                } else if (packetId == 18) {
                    // 0x12 Game Started Packet
                    int myPlayerId = in.readInt();
                    float mapWidth = in.readFloat();
                    float mapHeight = in.readFloat();

                    System.out.println("[SERVER] Game Started! My ID is: " + myPlayerId);
                    System.out.println("[SERVER] Map Dimensions: " + mapWidth + "x" + mapHeight);
                } else if (packetId == 19) {
                    // 0x13 Game State Tick
                    int numPlayers = in.readByte();

                    app.clearPlayers(); // Clear the old frame

                    for (int i = 0; i < numPlayers; i++) {
                        int id = in.readInt();
                        float x = in.readFloat();
                        float y = in.readFloat();
                        float angle = in.readFloat();
                        float mass = in.readFloat();
                        int score = in.readInt();

                        app.updatePlayer(id, x, y, angle, mass, score);
                    }

                    short numObjects = in.readShort();
                    // We will add the object loop here later when we make food!

                } else {
                    System.out.println("Unknown packet ID: " + packetId);
                }
            }
        } catch (IOException e) {
            System.out.println("Disconnected from server.");
        }
    }
}