import java.nio.charset.StandardCharsets;
import java.util.Scanner;

public class GameApp {
    public static void main(String[] args) {
        GameClient client = new GameClient();
        client.connect("localhost", 8080);

        String username = "Player1";
        client.sendPacket(1, username.getBytes());

        while (true){
            Scanner scanner = new Scanner(System.in);
            client.sendPacket(2,scanner.nextLine().getBytes());
        }
    }
}
