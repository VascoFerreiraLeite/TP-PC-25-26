import java.util.Scanner;
import javax.swing.*;
import java.awt.event.KeyAdapter;
import java.awt.event.KeyEvent;
import java.util.HashSet;
import java.util.Set;

public class GameApp {
    public static void main(String[] args) {
        GameClient client = new GameClient();
        client.connect("localhost", 8080);

        String username = "Player1";
        client.sendPacket(1, username.getBytes());

        JFrame frame=new JFrame("teste1");
        frame.setSize(500,500);
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

        Set<Character> pressionadas=new HashSet<>();

        frame.addKeyListener(new KeyAdapter() {
            public void keyPressed(KeyEvent e) {
                char key=e.getKeyChar();
                if (!pressionadas.contains(key)) {
                    pressionadas.add(key);
                    client.Key(1, key);
                }
            }
            public void keyReleased(KeyEvent e) {
                char key=e.getKeyChar();
                if (pressionadas.contains(key)) {
                    pressionadas.remove(key);
                    client.Key(0, key);
                }
            }
        });
        frame.setVisible(true);
    }
}
