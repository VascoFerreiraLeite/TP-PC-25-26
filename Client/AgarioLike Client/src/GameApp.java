import java.util.Scanner;
import processing.core.PApplet;
import java.util.HashSet;
import java.util.Set;


public class GameApp extend PApplet{
    public static void main(String[] args) {
        String username = "Player1";


        Set<Character> keys=new HashSet<>();

        public static void main(String[] args) {
            PApplet.main("GameApp");
        }

        public void settings() {
            size(500,500);
        }

        public void setup(){
            GameClient client = new GameClient();
            client.connect("localhost", 8080);
            client.sendPacket(1, username.getBytes());
        }

        public void draw(){
            background(255,255,255);
        }

        pressionadas=[];
        public void keyPressed(){
            if (!pressionadas.contain(key)){
                pressionadas.add(key);
                client.Key(1,key);
            }
        }

        public void keyReleased(){
            if (pressionadas.contain(key)){
                pressionadas.remove(key);
                client.Key(0,key);
            }
        }

    }
}
