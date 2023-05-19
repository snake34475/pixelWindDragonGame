using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class checkoutScence : MonoBehaviour
{
    // Start is called before the first frame update
    public Transform map;
    public string direction;//跳进取的方向
    public string Name;
    private Vector2 position;
    Scene scene;
    // Start is called before the first frame update
    void Start()
    {
        scene = SceneManager.GetActiveScene();
    }
    private void OnTriggerEnter2D(Collider2D other)
    {
        if (other.name == "player")
        {
            Debug.Log("Name0" + Name);
            SceneManager.LoadScene(Name);
           
        }
        
    }
    // Update is called once per frame
    void Update()
    {
        if (scene.name == Name)
        {
            Debug.Log("Name1" + GameObject.FindGameObjectWithTag("传送圈").transform.name);
            Vector3 checkoutPos = GameObject.FindGameObjectWithTag("传送圈").transform.position;
            GameObject.Find("player").transform.position = new Vector3(checkoutPos.x, checkoutPos.y - 1, checkoutPos.z);
        }
    }
}
