using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class npcdialog : MonoBehaviour
{
    public GameObject dialogObject;
    private float dilogTImer = 0;

    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
       if (dilogTImer > 0)
       {
           dilogTImer-= Time.deltaTime;
       }
       else
       {
           dilogTImer = 0;
           dialogObject.SetActive(false);
       }
    }
    public void openDilog()
    {
        dialogObject.SetActive(true);
        dilogTImer = 3f;
    }
}
