using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

public class rolemove : MonoBehaviour
{
    public float speed = 0.3f; //移动速度
    private Vector2 movePlay;
    public Rigidbody2D rigBody;
    private Animator animator;
    private KeyInterVal keyinterval = new KeyInterVal();
    public float runSpeed=1f;

    public GameObject shengzi;
    public class KeyInterVal
    {
       public string keyBoard;
       public float Timer;
    }
    // Start is called before the first frame update
    void Start()
    {
        animator = transform.Find("role").GetComponent<Animator>();
    }

    // Update is called once per frame
    void Update()
    {
        keyEnter();
    }

    private void FixedUpdate()
    {
        playMoveFn();
     
    }
    void playMoveFn()
    {
        Vector3 thisScale = this.transform.localScale;
        float moveX = Input.GetAxisRaw("Horizontal");
        float moveY = Input.GetAxisRaw("Vertical");

        //切换方向
        if (moveX != 0)
        {
            Vector3 roleScale = transform.Find("role").transform.localScale;
            roleScale.x = Math.Abs(transform.Find("role").transform.localScale.x) * moveX;
            transform.Find("role").transform.localScale = roleScale;
        }
        movePlay = new Vector2(moveX, moveY) * runSpeed;
        //位移
        Vector2 position = rigBody.position;

        position += movePlay * speed * Time.deltaTime;

        rigBody.MovePosition(position);
        animator.SetFloat("speed", movePlay.magnitude);
        animator.SetFloat("verticalX", moveX);
        animator.SetFloat("verticalY", moveY);

    }
    void keyEnter()
    {
        if ( Input.GetKeyDown(KeyCode.W))
        {
            setInterval("w");
        };
        if (Input.GetKeyDown(KeyCode.A))
        {
            setInterval("a");

        }

        if ( Input.GetKeyDown(KeyCode.S))
        {
            setInterval("s");

        }
        if (Input.GetKeyDown(KeyCode.D))
        {
            setInterval("d");
        }
        if (Input.GetKeyDown(KeyCode.Q)) //爆破石头
        {
            //判断不同的方向
            if (animator.GetFloat("verticalY") != 0)//先判断是否有按着上下
            {
                float posY = animator.GetFloat("verticalY")>0? transform.position.y + 0.8f : transform.position.y - 0.8f;
                GameObject.Find("Grid").transform.GetComponent<mapTile>().ExplosionLogic(new Vector3(transform.position.x, posY, transform.position.z));
            }
            else//否则按左右来判断
            {
                float posX = transform.Find("role").transform.localScale.x > 0 ? transform.position.x + 0.8f : transform.position.x - 0.8f;
                GameObject.Find("Grid").transform.GetComponent<mapTile>().ExplosionLogic(new Vector3(posX, transform.position.y, transform.position.z));

            }
        }
        if (Input.GetKeyDown(KeyCode.C))
        {
             //  Vector3 npctransform = movePlay;
          // if (animator.GetFloat("verticalY") != 0)//先判断是否有按着上下
          //  {
          //     npctransform = movePlay;
          // }
          //  else//否则按左右来判断
          //  {
          //     npctransform = new Vector2(transform.Find("role").transform.localScale.x > 0 ? 1 : 0, movePlay.y);
          //  }

            RaycastHit2D hit = Physics2D.Raycast(rigBody.position,new Vector2(transform.Find("role").transform.localScale.x > 0 ? 1 : 0,movePlay.y), 10f, LayerMask.GetMask("npc"));
            Debug.DrawRay(rigBody.position, new Vector2(transform.Find("role").transform.localScale.x > 0 ? 1 : 0, movePlay.y), Color.blue);
            if (hit.collider != null)
            {
                hit.collider.transform.GetComponent<npcdialog>().openDilog();
            }
        }
        if (Input.GetKey(KeyCode.E))
        {
            
            if (Input.GetMouseButtonDown(0))
            {
                Vector3 mousePos = Camera.main.ScreenToWorldPoint(Input.mousePosition);

                GameObject sz = Instantiate(shengzi);
                sz.transform.GetComponent<feibiao>().target = new Vector3(mousePos.x, mousePos.y, 0);
                sz.transform.position = new Vector3(transform.localPosition.x, transform.localPosition.y, 0);
                animator.SetBool("ischong", true);
            }
        }
       
    }
    private void setInterval(string key)
    {
        if (keyinterval.keyBoard == key && Time.time - keyinterval.Timer < 0.5f)///0.5秒之内按下有效
        {

            runSpeed = 2f;
        }
        else
        {
            runSpeed = 1f;

        }
        keyinterval.keyBoard = key;
        keyinterval.Timer = Time.time;
    }
}
