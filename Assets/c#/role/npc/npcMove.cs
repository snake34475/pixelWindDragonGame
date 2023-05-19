using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;


public class npcMove : MonoBehaviour
{
    public float speed = 1f; //移动速度
    private Vector2 movePlay;
    public Rigidbody2D rigBody;
    private Animator animator;
    private float moveTimer;
    private int moveX=1;
    private int moveY=0;
    public bool isMove = false;
    // Start is called before the first frame update
    void Start()
    {
        moveTimer = Time.time;
        animator = transform.Find("role").GetComponent<Animator>();
    }

    // Update is called once per frame
    void Update()
    {

    }
    private void FixedUpdate()
    {
        
        suiMove();

    }
    void playMoveFn()
    {
        //随机移动
        // moveX = UnityEngine.Random.Range(-1, 2);
        // moveY = UnityEngine.Random.Range(-1, 2);
            moveX = moveX == 1 ? -1 : 1;
        //切换方向
        if (moveX != 0)
        {
            Vector3 roleScale = transform.Find("role").transform.localScale;
            roleScale.x = Math.Abs(transform.Find("role").transform.localScale.x) * (moveX>0?1:-1);
            transform.Find("role").transform.localScale = roleScale;
        }
    }
    public void suiMove()
    {
          if (!transform.Find("Canvas").Find("npcDialog").gameObject.activeSelf)
         {
            Debug.Log("执行对话框关闭");
            if (Time.time - moveTimer > 5f)
            {

                playMoveFn();
                moveTimer = Time.time;
            }
            else
            {
                movePlay = new Vector2(moveX, moveY);
                Vector2 position = rigBody.position;
                position += movePlay * speed * Time.deltaTime;
                rigBody.MovePosition(position);
                animator.SetFloat("speed", movePlay.magnitude);
                animator.SetFloat("verticalX", moveX);
                animator.SetFloat("verticalY", moveY);

            }
        }
      else
      {
          animator.SetFloat("speed", 0);
          animator.SetFloat("verticalX", 0);
          animator.SetFloat("verticalY", 0);
      }
         
        }

}
