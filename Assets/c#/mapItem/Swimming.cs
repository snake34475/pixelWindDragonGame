using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Swimming : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        Debug.Log("我开始了");
    }

    // Update is called once per frame
    void Update()
    {
        
    }
/*    private void OnTriggerEnter2D(Collider2D other)
    {
        if (other.tag == "Player")
        {
            other.transform.Find("role").GetComponent<SpriteRenderer>().maskInteraction = SpriteMaskInteraction.VisibleInsideMask;
           // other.GetComponent<SpriteRenderer>().maskInteraction;
        }
    }*/
/*    private void OnTriggerStay2D(Collider2D collision)
    {
        
        
    }*/
    private void OnTriggerExit2D(Collider2D other)
    {
        other.transform.Find("role").GetComponent<SpriteRenderer>().maskInteraction = SpriteMaskInteraction.None;

    }
}
