public class GameApp {
    public static void main(String[] args) {
        GameClient client = new GameClient();
        client.connect("localhost", 8080);

        // Send Login Packet (ID: 1) with username "Player1"
        String username = "Player1";
        client.sendPacket(1, username.getBytes());
    }
}
